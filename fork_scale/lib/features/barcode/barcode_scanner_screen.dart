import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_theme.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final bool forRecipe;
  const BarcodeScannerScreen({super.key, this.forRecipe = false});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final barcode = capture.barcodes.firstOrNull;
    final raw = barcode?.rawValue;
    if (raw == null || raw.isEmpty) return;

    // Basic EAN/UPC sanity: digits only, 8–14 chars.
    if (!RegExp(r'^\d{8,14}$').hasMatch(raw)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read barcode — try again')),
      );
      return;
    }

    _handled = true;
    HapticFeedback.mediumImpact();
    _controller.stop();
    _navigateToResult(raw);
  }

  // Push (not pushReplacement) so the result can be forwarded back to whoever
  // pushed /scan. pushReplacement would complete the /scan future with null
  // immediately, breaking the forRecipe result-passing chain.
  Future<void> _navigateToResult(String barcode) async {
    final result = await context.push<Map<String, dynamic>?>(
      '/barcode-result',
      extra: {'barcode': barcode, 'forRecipe': widget.forRecipe},
    );
    if (mounted) context.pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan barcode'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Viewfinder overlay
          Center(
            child: Container(
              width: 260,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.accent, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const Align(
            alignment: Alignment(0, 0.55),
            child: Text(
              'Point at the barcode on the package',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
