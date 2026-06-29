import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/enums.dart';
import '../../models/meal.dart';
import '../../widgets/utensil_icons.dart';
import 'capture_controller.dart';

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isAnalysing = false;
  bool _cameraInitializing = false; // guard against concurrent inits
  Utensil _utensil = Utensil.fork;
  String? _errorMessage;
  String? _pendingSavedPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _loadDefaultUtensil();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeShowPrivacyDisclosure());
  }

  /// One-time disclosure that analysed photos are sent to Google Gemini. Shown
  /// before the first capture; acknowledgement persisted so it never re-shows.
  Future<void> _maybeShowPrivacyDisclosure() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('privacy_ack') ?? false) return;
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l.privacyTitle),
        content: Text(l.privacyBody),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.privacyAccept),
          ),
        ],
      ),
    );
    await prefs.setBool('privacy_ack', true);
  }

  Future<void> _loadDefaultUtensil() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('default_utensil') ?? 'fork';
    if (mounted) setState(() => _utensil = Utensil.parse(saved));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      // Null _controller first so the preview widget shows a spinner instead
      // of trying to render from a disposed controller.
      final old = _controller;
      if (mounted) setState(() => _controller = null);
      old?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    // Prevent two simultaneous init calls (e.g. rapid background→foreground).
    if (_cameraInitializing) return;
    _cameraInitializing = true;
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() =>
              _errorMessage = AppLocalizations.of(context).captureNoCamera);
        }
        return;
      }
      final controller = CameraController(
        _cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      try {
        await controller.initialize();
      } catch (e) {
        await controller.dispose();
        if (mounted) {
          setState(() => _errorMessage =
              AppLocalizations.of(context).captureCameraFailed('$e'));
        }
        return;
      }
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } finally {
      _cameraInitializing = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _onShutter() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final xfile = await _controller!.takePicture();
    await _analyse(File(xfile.path));
  }

  Future<void> _onGallery() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
    if (xfile == null) return;
    await _analyse(File(xfile.path));
  }

  Future<void> _analyse(File file) async {
    // Await the FutureProvider so we always get the resolved key, not the
    // AsyncLoading null that exists for a brief moment after a cold start.
    await ref.read(geminiApiKeyProvider.future);
    final controller = ref.read(captureControllerProvider);
    if (controller == null) {
      _showApiKeyError();
      return;
    }

    _pendingSavedPath = null;
    setState(() => _isAnalysing = true);
    try {
      final lengths = await ref.read(utensilLengthsProvider.future);
      final lengthCm = lengths[_utensil.name] ?? 18.5;
      final outcome = await controller.analyze(
        source: file,
        utensil: _utensil,
        utensilLengthCm: lengthCm,
      );
      if (!mounted) return;
      _handleOutcome(outcome);
    } finally {
      if (mounted) setState(() => _isAnalysing = false);
    }
  }

  void _handleOutcome(CaptureOutcome outcome) {
    final l = AppLocalizations.of(context);
    switch (outcome) {
      case CaptureSuccess(:final result):
        context.push('/results', extra: result);
      case CaptureApiKeyError():
        _showApiKeyError();
      case CaptureRetryable(:final reason, :final savedPath):
        _pendingSavedPath = savedPath;
        _showRetryError(switch (reason) {
          CaptureRetryReason.timeout => l.captureTimedOut,
          CaptureRetryReason.rateLimit => l.captureRateLimit,
          CaptureRetryReason.overloaded => l.captureOverloaded,
        });
      case CaptureError(:final kind, :final statusCode, :final detail):
        _showError(
          switch (kind) {
            CaptureErrorKind.apiError =>
              l.captureApiError(statusCode ?? 0),
            CaptureErrorKind.responseCutOff => l.captureResponseCutOff,
            CaptureErrorKind.couldNotRead => l.captureCouldNotRead,
            CaptureErrorKind.unexpected => l.captureUnexpectedError,
          },
          detail: detail,
        );
    }
  }

  void _showRetryError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 8),
        action: _pendingSavedPath != null
            ? SnackBarAction(
                label: AppLocalizations.of(context).captureSaveForLater,
                onPressed: _savePending)
            : null,
      ),
    );
  }

  Future<void> _savePending() async {
    final path = _pendingSavedPath;
    if (path == null) return;
    _pendingSavedPath = null;
    final controller = ref.read(captureControllerProvider);
    if (controller == null) return;
    await controller.saveForLater(savedPath: path, utensil: _utensil);
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.capturePhotoSaved),
        action: SnackBarAction(
          label: l.navHistory,
          onPressed: () => context.go('/history'),
        ),
      ),
    );
  }

  void _showApiKeyError() {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.captureApiKeyMissing),
        action: SnackBarAction(
          label: l.navSettings,
          onPressed: () => context.go('/settings'),
        ),
      ),
    );
  }

  void _showError(String message, {String? detail}) {
    // Raw API bodies / model text can contain sensitive request echoes, so the
    // diagnostics dialog is only offered in debug builds. Release users see the
    // friendly message only.
    final showDetail = detail != null && kDebugMode;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: showDetail
            ? SnackBarAction(
                label: AppLocalizations.of(context).actionDetails,
                onPressed: () => _showErrorDetail(message, detail),
              )
            : null,
      ),
    );
  }

  void _showErrorDetail(String message, String detail) {
    final l = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.captureErrorDetail),
        content: SingleChildScrollView(
          child: SelectableText(
            detail,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: '$message\n\n$detail'));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l.captureCopied)),
              );
            },
            child: Text(l.actionCopy),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.actionClose),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildViewfinder(),
          if (!_isAnalysing) _CameraGuide(utensil: _utensil),
          _buildOverlay(),
          if (_isAnalysing) _buildAnalysingOverlay(),
        ],
      ),
    );
  }

  Widget _buildViewfinder() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_errorMessage!, style: const TextStyle(color: Colors.white)),
        ),
      );
    }
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return CameraPreview(_controller!);
  }

  Widget _buildOverlay() {
    return SafeArea(
      child: Column(
        children: [
          // Top bar: instruction banner + barcode button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _InstructionBanner(),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                  tooltip: AppLocalizations.of(context).captureScanBarcode,
                  onPressed: () => context.push('/scan'),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Recent meals strip (CR-03-C)
          _RecentMealsStrip(),
          // Utensil toggle + controls
          Padding(
            padding: const EdgeInsets.only(bottom: 16, left: 32, right: 32),
            child: Column(
              children: [
                _UtensilToggle(
                  utensil: _utensil,
                  onChanged: (v) => setState(() => _utensil = v),
                  lengths: ref.watch(utensilLengthsProvider).value ??
                      {'fork': 18.5, 'knife': 21.0, 'spoon': 20.0},
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _GalleryButton(onTap: _onGallery),
                    _ShutterButton(onTap: _onShutter),
                    const SizedBox(width: 56), // balance
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.accent),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).captureAnalysing,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recent meals strip ────────────────────────────────────────────────────────

final _recentMealsProvider = FutureProvider.autoDispose<_RecentMealsData>((ref) async {
  ref.watch(mealsChangesProvider);
  final repo = ref.read(mealsRepositoryProvider);
  final recent = await repo.getRecentDistinct(limit: 5);
  final todayNames = await repo.getMealNamesToday();
  return _RecentMealsData(recent: recent, todayNames: todayNames);
});

class _RecentMealsData {
  final List<Meal> recent;
  final Set<String> todayNames;
  const _RecentMealsData({required this.recent, required this.todayNames});
}

class _RecentMealsStrip extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final dataAsync = ref.watch(_recentMealsProvider);
    final meals = dataAsync.value?.recent ?? <Meal>[];
    final todayNames = dataAsync.value?.todayNames ?? <String>{};
    if (meals.isEmpty) return const SizedBox.shrink();

    // Grow the strip with the user's text scale so the chips never clip at
    // large accessibility font sizes (capped so it can't dominate the screen).
    final textScale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.6);
    return SizedBox(
      height: 44 * textScale,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: meals.length,
        itemBuilder: (context, i) {
          final meal = meals[i];
          final name = meal.name ?? '';
          final kcal = meal.totalKcal.round();
          final loggedToday = todayNames.contains(name);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: loggedToday
                  ? null
                  : () async {
                      await ref
                          .read(mealsRepositoryProvider)
                          .copyMealToToday(meal);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l.captureMealLogged(name))),
                        );
                      }
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: loggedToday
                      ? Colors.white12
                      : Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: loggedToday ? Colors.white24 : Colors.white38,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: loggedToday ? Colors.white38 : Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    loggedToday ? l.captureLoggedToday : l.captureKcal(kcal),
                    style: TextStyle(
                      color: loggedToday ? Colors.white38 : AppColors.accent,
                      fontSize: 11,
                    ),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InstructionBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        AppLocalizations.of(context).captureHint,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}

class _UtensilToggle extends StatelessWidget {
  final Utensil utensil;
  final ValueChanged<Utensil> onChanged;
  final Map<String, double> lengths;

  const _UtensilToggle({
    required this.utensil,
    required this.onChanged,
    required this.lengths,
  });

  String _cm(String key) => '${(lengths[key] ?? 0).toStringAsFixed(1)} cm';

  static const _style = TextStyle(color: Colors.white, fontSize: 13);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Tab(
            label: Row(mainAxisSize: MainAxisSize.min, children: [
              const ForkIcon(size: 13),
              const SizedBox(width: 5),
              Text(_cm('fork'), style: _style),
            ]),
            semanticLabel: 'Fork ${_cm('fork')}',
            value: Utensil.fork,
            current: utensil,
            onTap: onChanged,
          ),
          _Tab(
            label: Row(mainAxisSize: MainAxisSize.min, children: [
              const KnifeIcon(size: 13),
              const SizedBox(width: 5),
              Text(_cm('knife'), style: _style),
            ]),
            semanticLabel: 'Knife ${_cm('knife')}',
            value: Utensil.knife,
            current: utensil,
            onTap: onChanged,
          ),
          _Tab(
            label: Row(mainAxisSize: MainAxisSize.min, children: [
              const SpoonIcon(size: 13),
              const SizedBox(width: 5),
              Text(_cm('spoon'), style: _style),
            ]),
            semanticLabel: 'Spoon ${_cm('spoon')}',
            value: Utensil.spoon,
            current: utensil,
            onTap: onChanged,
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final Widget label;
  final String semanticLabel;
  final Utensil value;
  final Utensil current;
  final ValueChanged<Utensil> onTap;

  const _Tab({
    required this.label,
    required this.semanticLabel,
    required this.value,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = value == current;
    return Semantics(
      button: true,
      selected: active,
      label: semanticLabel,
      child: GestureDetector(
        onTap: () => onTap(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: ExcludeSemantics(child: label),
        ),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ShutterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).captureTakePhoto,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            color: Colors.white24,
          ),
          child: const Center(
            child: CircleAvatar(radius: 28, backgroundColor: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _GalleryButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GalleryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l.capturePickFromGallery,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white38),
          ),
          child: Icon(Icons.photo_library,
              color: Colors.white, semanticLabel: l.captureGallery),
        ),
      ),
    );
  }
}

// ── Camera framing guide ──────────────────────────────────────────────────────

class _CameraGuide extends StatelessWidget {
  final Utensil utensil;
  const _CameraGuide({required this.utensil});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final r = w * 0.37;
      final cx = w / 2;
      final cy = h * 0.42;
      return Stack(
        children: [
          CustomPaint(
            painter: _GuidePainter(cx: cx, cy: cy, r: r),
            child: const SizedBox.expand(),
          ),
          Positioned(
            left: cx - 18,
            top: cy - r - 22,
            child: _badge(Text(AppLocalizations.of(context).capturePlate,
                style: const TextStyle(color: Colors.white70, fontSize: 11))),
          ),
          Positioned(
            left: cx - r - 64,
            top: cy - 10,
            child: _utensilBadge,
          ),
        ],
      );
    });
  }

  Widget get _utensilBadge => _badge(switch (utensil) {
        Utensil.fork => const ForkIcon(size: 11, color: Colors.white70),
        Utensil.knife => const KnifeIcon(size: 11, color: Colors.white70),
        Utensil.spoon => const SpoonIcon(size: 11, color: Colors.white70),
      });

  Widget _badge(Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(4),
        ),
        child: child,
      );
}

class _GuidePainter extends CustomPainter {
  final double cx, cy, r;
  const _GuidePainter({required this.cx, required this.cy, required this.r});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(Offset(cx, cy), r, paint);

    final ux = cx - r - 16;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(ux, cy), width: 10, height: r * 1.25),
        const Radius.circular(5),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GuidePainter old) =>
      old.cx != cx || old.cy != cy || old.r != r;
}

