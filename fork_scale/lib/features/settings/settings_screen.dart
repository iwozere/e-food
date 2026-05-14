import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter/services.dart';

import '../../core/services/gemini_service.dart';
import '../../core/services/providers.dart';
import '../../core/theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyCtrl = TextEditingController();
  final _forkLengthCtrl = TextEditingController();
  final _knifeLengthCtrl = TextEditingController();
  final _spoonLengthCtrl = TextEditingController();
  bool _obscureKey = true;
  bool _validating = false;
  String _utensil = 'fork';
  int _dailyGoal = 2000;
  double _forkLengthCm = 18.5;
  double _knifeLengthCm = 21.0;
  double _spoonLengthCm = 20.0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _forkLengthCtrl.dispose();
    _knifeLengthCtrl.dispose();
    _spoonLengthCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    // One-time migration: move key from flutter_secure_storage → SharedPreferences.
    // Handles users who had the key saved before this change.
    String? key = prefs.getString('gemini_api_key');
    if (key == null) {
      try {
        const old = FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );
        final migrated = await old.read(key: 'gemini_api_key');
        if (migrated != null && migrated.isNotEmpty) {
          await prefs.setString('gemini_api_key', migrated);
          await old.delete(key: 'gemini_api_key');
          key = migrated;
        }
      } catch (_) {}
    }

    final forkCm = prefs.getDouble('fork_length_cm') ?? 18.5;
    final knifeCm = prefs.getDouble('knife_length_cm') ?? 21.0;
    final spoonCm = prefs.getDouble('spoon_length_cm') ?? 20.0;
    setState(() {
      _apiKeyCtrl.text = key ?? '';
      _utensil = prefs.getString('default_utensil') ?? 'fork';
      _dailyGoal = prefs.getInt('daily_goal') ?? 2000;
      _forkLengthCm = forkCm;
      _knifeLengthCm = knifeCm;
      _spoonLengthCm = spoonCm;
      _forkLengthCtrl.text = forkCm.toStringAsFixed(1);
      _knifeLengthCtrl.text = knifeCm.toStringAsFixed(1);
      _spoonLengthCtrl.text = spoonCm.toStringAsFixed(1);
      _loading = false;
    });
    if (key != null && key.isNotEmpty) {
      ref.invalidate(geminiApiKeyProvider);
    }
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyCtrl.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    final prefs = await SharedPreferences.getInstance();

    if (key.isEmpty) {
      await prefs.remove('gemini_api_key');
      ref.invalidate(geminiApiKeyProvider);
      messenger.showSnackBar(const SnackBar(content: Text('API key removed')));
      return;
    }

    setState(() => _validating = true);
    final result = await validateGeminiKey(key);
    if (!mounted) return;
    setState(() => _validating = false);

    switch (result) {
      case KeyValidationResult.valid:
        await prefs.setString('gemini_api_key', key);
        ref.invalidate(geminiApiKeyProvider);
        messenger.showSnackBar(SnackBar(
          content: const Text('API key saved and verified ✓'),
          backgroundColor: Colors.green.shade700,
        ));
      case KeyValidationResult.invalid:
        messenger.showSnackBar(SnackBar(
          content: const Text('Invalid API key — not saved. Check and try again.'),
          backgroundColor: AppColors.error,
        ));
      case KeyValidationResult.networkError:
        // Save anyway — user may be offline, don't block them
        await prefs.setString('gemini_api_key', key);
        ref.invalidate(geminiApiKeyProvider);
        messenger.showSnackBar(SnackBar(
          content: const Text('Key saved (could not verify — no internet)'),
          backgroundColor: Colors.orange.shade700,
        ));
    }
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_utensil', _utensil);
    await prefs.setInt('daily_goal', _dailyGoal);
    await prefs.setDouble('fork_length_cm', _forkLengthCm);
    await prefs.setDouble('knife_length_cm', _knifeLengthCm);
    await prefs.setDouble('spoon_length_cm', _spoonLengthCm);
    ref.invalidate(dailyGoalProvider);
    ref.invalidate(utensilLengthsProvider);
  }

  Future<String> _storageSummary() async {
    final docs = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(docs.path, 'meal_photos'));
    int photoBytes = 0;
    if (photosDir.existsSync()) {
      await for (final f in photosDir.list()) {
        if (f is File) photoBytes += await f.length();
      }
    }
    final dbFile = File(p.join(docs.path, 'fork_scale.db'));
    final dbBytes = dbFile.existsSync() ? await dbFile.length() : 0;
    return '${_mb(dbBytes)} DB · ${_mb(photoBytes)} photos';
  }

  String _mb(int bytes) => '${(bytes / 1048576).toStringAsFixed(1)} MB';

  Future<void> _exportCsv() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await ref.read(mealsRepositoryProvider).exportCsv();
      await Share.shareXFiles(
        [XFile(path)],
        subject: 'ForkScale meal history',
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _clearHistory() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all history?'),
        content: const Text('All meals and photos will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete all', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final docs = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(docs.path, 'meal_photos'));
    if (photosDir.existsSync()) await photosDir.delete(recursive: true);
    final dbFile = File(p.join(docs.path, 'fork_scale.db'));
    if (dbFile.existsSync()) await dbFile.delete();
    messenger.showSnackBar(const SnackBar(content: Text('History cleared. Restart the app.')));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader('Capture'),
          Card(
            child: RadioGroup<String>(
              groupValue: _utensil,
              onChanged: (v) {
                if (v == null) return;
                setState(() => _utensil = v);
                _savePrefs();
              },
              child: Column(
                children: [
                  _UtensilTile(
                    emoji: '🍴',
                    label: 'Fork',
                    value: 'fork',
                    ctrl: _forkLengthCtrl,
                    onLengthChanged: (v) { setState(() => _forkLengthCm = v); _savePrefs(); },
                  ),
                  const Divider(height: 0, indent: 56),
                  _UtensilTile(
                    emoji: '🔪',
                    label: 'Knife',
                    value: 'knife',
                    ctrl: _knifeLengthCtrl,
                    onLengthChanged: (v) { setState(() => _knifeLengthCm = v); _savePrefs(); },
                  ),
                  const Divider(height: 0, indent: 56),
                  _UtensilTile(
                    emoji: '🥄',
                    label: 'Spoon',
                    value: 'spoon',
                    ctrl: _spoonLengthCtrl,
                    onLengthChanged: (v) { setState(() => _spoonLengthCm = v); _savePrefs(); },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionHeader('Daily calorie goal'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text('Goal (kcal)'),
                  const Spacer(),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      controller:
                          TextEditingController(text: _dailyGoal.toString()),
                      onChanged: (v) {
                        final parsed = int.tryParse(v);
                        if (parsed != null && parsed > 0) {
                          _dailyGoal = parsed;
                          _savePrefs();
                        }
                      },
                      decoration: const InputDecoration(border: UnderlineInputBorder()),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionHeader('AI Model'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text('Gemini 2.5 Flash',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Active',
                            style: TextStyle(color: Colors.green, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _apiKeyCtrl,
                    obscureText: _obscureKey,
                    decoration: InputDecoration(
                      labelText: 'Gemini API Key',
                      hintText: 'AIza…',
                      suffixIcon: IconButton(
                        icon: Icon(_obscureKey ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscureKey = !_obscureKey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _ApiKeyHint(),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _validating ? null : _saveApiKey,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(100, 40),
                      ),
                      child: _validating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Save key'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'On-device model (coming soon)',
                    style: TextStyle(color: AppColors.subtle, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionHeader('Storage'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<String>(
                    future: _storageSummary(),
                    builder: (context, snap) => Text(
                      snap.data ?? 'Calculating…',
                      style: const TextStyle(color: AppColors.subtle),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _exportCsv,
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Export to CSV'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _clearHistory,
                    icon: const Icon(Icons.delete_forever, color: AppColors.error),
                    label: const Text('Clear all history',
                        style: TextStyle(color: AppColors.error)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _ApiKeyHint extends StatelessWidget {
  static final _url = Uri.parse('https://aistudio.google.com/app/apikey');

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 14, color: AppColors.subtle),
        const SizedBox(width: 4),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 12, color: AppColors.subtle),
              children: [
                const TextSpan(
                  text: 'Free — no credit card needed. Sign in with a Google account at ',
                ),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: () => launchUrl(_url, mode: LaunchMode.externalApplication),
                    child: const Text(
                      'Google AI Studio',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const TextSpan(text: ', then tap Get API key → Create API key.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _UtensilTile extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final TextEditingController ctrl;
  final ValueChanged<double> onLengthChanged;

  const _UtensilTile({
    required this.emoji,
    required this.label,
    required this.value,
    required this.ctrl,
    required this.onLengthChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(
      value: value,
      title: Text('$emoji $label'),
      secondary: SizedBox(
        width: 80,
        child: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            suffixText: 'cm',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            isDense: true,
          ),
          onChanged: (v) {
            final parsed = double.tryParse(v);
            if (parsed != null && parsed > 0) onLengthChanged(parsed);
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.subtle,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
