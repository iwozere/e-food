import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/gemini_service.dart';
import '../../core/services/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../models/analysis_result.dart';
import '../../models/enums.dart';
import '../../models/meal.dart';

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
        if (mounted) setState(() => _errorMessage = 'No camera available on this device.');
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
        if (mounted) setState(() => _errorMessage = 'Camera failed to start: $e');
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
    final gemini = ref.read(geminiServiceProvider);
    if (gemini == null) {
      _showApiKeyError();
      return;
    }

    _pendingSavedPath = null;
    setState(() => _isAnalysing = true);
    try {
      final imageService = ref.read(imageServiceProvider);
      final filename = '${const Uuid().v4()}.jpg';

      final (:apiBytes, :savedPath) =
          await imageService.processCapture(file, filename: filename);
      _pendingSavedPath = savedPath;

      final lengths = await ref.read(utensilLengthsProvider.future);
      final lengthCm = lengths[_utensil.name] ?? 18.5;

      final result = await gemini.analyzeImage(
        imageBytes: apiBytes,
        utensil: _utensil.name,
        utensilLengthCm: lengthCm,
      );

      _pendingSavedPath = null;
      if (!mounted) return;
      context.push(
        '/results',
        extra: AnalysisResult(
          utensilDetected: result.utensilDetected,
          scaleConfidence: result.scaleConfidence,
          items: result.items,
          totalKcal: result.totalKcal,
          notes: result.notes,
          photoPath: savedPath,
          utensil: _utensil.name,
        ),
      );
    } on TimeoutException {
      _showRetryError('Request timed out — save photo for later?');
    } on GeminiRateLimitException {
      _showRetryError('Rate limit reached — save photo for later?');
    } on GeminiApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        _discardPendingPhoto();
        _showApiKeyError();
      } else if (e.statusCode == 503) {
        _showRetryError('Gemini is overloaded — save photo for later?');
      } else {
        _discardPendingPhoto();
        _showError('API error (${e.statusCode}).', detail: e.body);
      }
    } on GeminiParseException catch (e) {
      _discardPendingPhoto();
      final msg = e.truncated
          ? 'Response was cut off — please retake the photo.'
          : 'Could not read results — please retake the photo.';
      _showError(msg, detail: e.rawText);
    } catch (e) {
      _discardPendingPhoto();
      _showError('An unexpected error occurred.', detail: e.toString());
    } finally {
      if (mounted) setState(() => _isAnalysing = false);
    }
  }

  void _discardPendingPhoto() {
    final path = _pendingSavedPath;
    if (path == null) return;
    _pendingSavedPath = null;
    ref.read(imageServiceProvider).deletePhoto(path);
  }

  void _showRetryError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 8),
        action: _pendingSavedPath != null
            ? SnackBarAction(label: 'Save for later', onPressed: _savePending)
            : null,
      ),
    );
  }

  Future<void> _savePending() async {
    final path = _pendingSavedPath;
    if (path == null) return;
    _pendingSavedPath = null;
    final repo = ref.read(mealsRepositoryProvider);
    await repo.insertMeal(Meal(
      createdAt: DateTime.now(),
      photoPath: path,
      totalKcal: 0,
      utensil: _utensil,
      modelUsed: 'gemini',
      mealType: Meal.detectTypeFromTime(),
      pending: true,
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Photo saved — analyze it any time from History.'),
        action: SnackBarAction(
          label: 'History',
          onPressed: () => context.go('/history'),
        ),
      ),
    );
  }

  void _showApiKeyError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Gemini API key missing or invalid.'),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: () => context.go('/settings'),
        ),
      ),
    );
  }

  void _showError(String message, {String? detail}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: detail != null
            ? SnackBarAction(
                label: 'Details',
                onPressed: () => _showErrorDetail(message, detail),
              )
            : null,
      ),
    );
  }

  void _showErrorDetail(String message, String detail) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error detail'),
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
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
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
                  tooltip: 'Scan barcode',
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
                  lengths: ref.watch(utensilLengthsProvider).valueOrNull ??
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
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.accent),
            SizedBox(height: 16),
            Text(
              'Analysing…',
              style: TextStyle(color: Colors.white, fontSize: 18),
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
    final dataAsync = ref.watch(_recentMealsProvider);
    final meals = dataAsync.valueOrNull?.recent ?? <Meal>[];
    final todayNames = dataAsync.valueOrNull?.todayNames ?? <String>{};
    if (meals.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
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
                          SnackBar(content: Text('$name logged')),
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
                    loggedToday ? 'Logged today' : '$kcal kcal',
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
      child: const Text(
        'Place utensil beside the plate as scale',
        style: TextStyle(color: Colors.white, fontSize: 12),
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
              const _ForkIcon(size: 13),
              const SizedBox(width: 5),
              Text(_cm('fork'), style: _style),
            ]),
            semanticLabel: 'Fork ${_cm('fork')}',
            value: Utensil.fork,
            current: utensil,
            onTap: onChanged,
          ),
          _Tab(
            label: Text('🔪 ${_cm('knife')}', style: _style),
            semanticLabel: 'Knife ${_cm('knife')}',
            value: Utensil.knife,
            current: utensil,
            onTap: onChanged,
          ),
          _Tab(
            label: Text('🥄 ${_cm('spoon')}', style: _style),
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
      label: 'Take photo',
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
    return Semantics(
      button: true,
      label: 'Pick from gallery',
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
          child: const Icon(Icons.photo_library, color: Colors.white,
              semanticLabel: 'Gallery'),
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
            child: _badge(const Text('Plate',
                style: TextStyle(color: Colors.white70, fontSize: 11))),
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
        Utensil.fork => const _ForkIcon(size: 11, color: Colors.white70),
        Utensil.knife => const Text('🔪',
            style: TextStyle(color: Colors.white70, fontSize: 11)),
        Utensil.spoon => const Text('🥄',
            style: TextStyle(color: Colors.white70, fontSize: 11)),
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

// ── Fork icon (CustomPaint) ───────────────────────────────────────────────────
// Used in the utensil toggle and camera guide badge. No standard fork-only
// Unicode emoji exists, so we draw a 3-tine fork with a handle.

class _ForkIcon extends StatelessWidget {
  final double size;
  final Color color;
  const _ForkIcon({this.size = 14, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size * 0.55, size),
      painter: _ForkPainter(color: color),
    );
  }
}

class _ForkPainter extends CustomPainter {
  final Color color;
  const _ForkPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final sw = w * 0.20;
    final paint = Paint()
      ..color = color
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Handle: center, from bottom up to 55% height
    canvas.drawLine(Offset(w / 2, h), Offset(w / 2, h * 0.52), paint);

    // Shoulder: horizontal bridge connecting tines to handle
    canvas.drawLine(Offset(sw / 2, h * 0.52), Offset(w - sw / 2, h * 0.52), paint);

    // 3 tines evenly spaced across the width
    for (var i = 0; i < 3; i++) {
      final x = sw / 2 + (w - sw) * i / 2;
      canvas.drawLine(Offset(x, h * 0.52), Offset(x, h * 0.05), paint);
    }
  }

  @override
  bool shouldRepaint(_ForkPainter old) => old.color != color;
}
