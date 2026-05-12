import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/gemini_service.dart';
import '../../core/services/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../models/analysis_result.dart';

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
  String _utensil = 'fork';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isEmpty) {
      setState(() => _errorMessage = 'No camera available on this device.');
      return;
    }
    final controller = CameraController(
      _cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await controller.initialize();
    if (!mounted) return;
    setState(() => _controller = controller);
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
    final gemini = ref.read(geminiServiceProvider);
    if (gemini == null) {
      _showApiKeyError();
      return;
    }

    setState(() => _isAnalysing = true);
    try {
      final imageService = ref.read(imageServiceProvider);
      final filename = '${const Uuid().v4()}.jpg';

      // Resize for API and save for history in parallel
      final futures = await Future.wait([
        imageService.resizeForApi(file),
        imageService.saveForHistory(file, filename: filename),
      ]);
      final apiBytes = futures[0] as dynamic;
      final savedPath = futures[1] as String;

      final result = await gemini.analyzeImage(
        imageBytes: apiBytes,
        utensil: _utensil,
      );

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
          utensil: _utensil,
        ),
      );
    } on GeminiRateLimitException {
      _showError('Rate limit reached. Please wait a minute and try again.');
    } on GeminiApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        _showApiKeyError();
      } else {
        _showError('API error (${e.statusCode}). Please try again.');
      }
    } on GeminiParseException {
      _showError('Could not read results — please retake the photo.');
    } catch (e) {
      _showError('An unexpected error occurred: $e');
    } finally {
      if (mounted) setState(() => _isAnalysing = false);
    }
  }

  void _showApiKeyError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Gemini API key missing or invalid.'),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: () => context.push('/settings'),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
          // Top bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _InstructionBanner(),
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onPressed: () => context.push('/settings'),
                ),
              ],
            ),
          ),
          // History shortcut
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(
                icon: const Icon(Icons.history, color: Colors.white),
                onPressed: () => context.push('/history'),
              ),
            ),
          ),
          const Spacer(),
          // Utensil toggle + controls
          Padding(
            padding: const EdgeInsets.only(bottom: 32, left: 32, right: 32),
            child: Column(
              children: [
                _UtensilToggle(
                  utensil: _utensil,
                  onChanged: (v) => setState(() => _utensil = v),
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
        'Place a fork or knife beside the plate',
        style: TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}

class _UtensilToggle extends StatelessWidget {
  final String utensil;
  final ValueChanged<String> onChanged;

  const _UtensilToggle({required this.utensil, required this.onChanged});

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
          _Tab(label: '🍴 Fork (18.5 cm)', value: 'fork', current: utensil, onTap: onChanged),
          _Tab(label: '🔪 Knife (21 cm)', value: 'knife', current: utensil, onTap: onChanged),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onTap;

  const _Tab({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = value == current;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ShutterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
    );
  }
}

class _GalleryButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GalleryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white38),
        ),
        child: const Icon(Icons.photo_library, color: Colors.white),
      ),
    );
  }
}
