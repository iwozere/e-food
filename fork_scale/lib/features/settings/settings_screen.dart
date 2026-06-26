import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/backup_service.dart';

import 'package:flutter/services.dart';

import '../../core/services/gemini_service.dart';
import '../../core/database/app_database.dart';
import '../../core/services/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/utensil_icons.dart';
import '../history/history_providers.dart';

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
  final _dailyGoalCtrl = TextEditingController();
  bool _obscureKey = true;
  bool _validating = false;
  String _utensil = 'fork';
  int _dailyGoal = 2000;
  double _forkLengthCm = 18.5;
  double _knifeLengthCm = 21.0;
  double _spoonLengthCm = 20.0;
  bool _loading = true;
  Future<String>? _storageFuture;

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
    _dailyGoalCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    // Read the key through the provider, which owns the secure-storage read and
    // the one-time plaintext-prefs → secure-storage migration.
    final key = await ref.read(geminiApiKeyProvider.future);

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
      _dailyGoalCtrl.text = _dailyGoal.toString();
      _storageFuture = _storageSummary(AppLocalizations.of(context));
      _loading = false;
    });
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyCtrl.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);

    if (key.isEmpty) {
      await geminiKeyStorage.delete(key: geminiKeyStorageKey);
      ref.invalidate(geminiApiKeyProvider);
      messenger.showSnackBar(SnackBar(content: Text(l.settingsApiKeyRemoved)));
      return;
    }

    setState(() => _validating = true);
    final result = await validateGeminiKey(key);
    if (!mounted) return;
    setState(() => _validating = false);

    switch (result) {
      case KeyValidationResult.valid:
        await geminiKeyStorage.write(key: geminiKeyStorageKey, value: key);
        ref.invalidate(geminiApiKeyProvider);
        messenger.showSnackBar(SnackBar(
          content: Text(l.settingsApiKeySaved),
          backgroundColor: Colors.green.shade700,
        ));
      case KeyValidationResult.invalid:
        messenger.showSnackBar(SnackBar(
          content: Text(l.settingsApiKeyInvalid),
          backgroundColor: AppColors.error,
        ));
      case KeyValidationResult.networkError:
        // Save anyway — user may be offline, don't block them
        await geminiKeyStorage.write(key: geminiKeyStorageKey, value: key);
        ref.invalidate(geminiApiKeyProvider);
        messenger.showSnackBar(SnackBar(
          content: Text(l.settingsApiKeySavedNoVerify),
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

  Future<String> _storageSummary(AppLocalizations l) async {
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
    return l.settingsStorageSummary(_mb(dbBytes), _mb(photoBytes));
  }

  String _mb(int bytes) => '${(bytes / 1048576).toStringAsFixed(1)} MB';

  Future<void> _createBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    try {
      await BackupService.createBackup();
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(l.settingsBackupFailed('$e'))));
    }
  }

  Future<void> _restoreBackup() async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.settingsRestoreTitle),
        content: Text(l.settingsRestoreBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.actionCancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.actionRestore),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final restored = await BackupService.restoreBackup();
      if (!mounted) return;
      if (restored) {
        ref.invalidate(historyMealsProvider);
        ref.invalidate(historyDayTotalProvider);
        ref.invalidate(historyWeeklyKcalProvider);
        messenger.showSnackBar(
          SnackBar(
            content: Text(l.settingsBackupRestored),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
          SnackBar(content: Text(l.settingsRestoreFailed('$e'))));
    }
  }

  Future<void> _exportCsv() async {
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    try {
      final path = await ref.read(mealsRepositoryProvider).exportCsv();
      await Share.shareXFiles(
        [XFile(path)],
        subject: 'ForkScale meal history',
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.settingsExportFailed('$e'))),
      );
    }
  }

  Future<void> _clearHistory() async {
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.settingsClearTitle),
        content: Text(l.settingsClearBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.actionCancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.settingsDeleteAll,
                style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final docs = await getApplicationDocumentsDirectory();

    // Close connections before touching the files.
    await AppDatabase.closeAll();

    // Delete DB and its WAL sidecars.
    final dbBase = p.join(docs.path, 'fork_scale.db');
    for (final ext in ['', '-wal', '-shm']) {
      final f = File('$dbBase$ext');
      if (await f.exists()) await f.delete();
    }

    // Delete photos.
    final photosDir = Directory(p.join(docs.path, 'meal_photos'));
    if (photosDir.existsSync()) await photosDir.delete(recursive: true);

    // Invalidate all providers that hold meal data — screens reload from the new empty DB.
    ref.invalidate(historyMealsProvider);
    ref.invalidate(historyDayTotalProvider);
    ref.invalidate(historyWeeklyKcalProvider);

    if (mounted) {
      messenger.showSnackBar(SnackBar(content: Text(l.settingsHistoryCleared)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader(l.settingsSectionCapture),
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
                    icon: const ForkIcon(size: 18, color: AppColors.primary),
                    label: l.settingsFork,
                    value: 'fork',
                    ctrl: _forkLengthCtrl,
                    onLengthChanged: (v) { setState(() => _forkLengthCm = v); _savePrefs(); },
                  ),
                  const Divider(height: 0, indent: 56),
                  _UtensilTile(
                    icon: const KnifeIcon(size: 18, color: AppColors.primary),
                    label: l.settingsKnife,
                    value: 'knife',
                    ctrl: _knifeLengthCtrl,
                    onLengthChanged: (v) { setState(() => _knifeLengthCm = v); _savePrefs(); },
                  ),
                  const Divider(height: 0, indent: 56),
                  _UtensilTile(
                    icon: const SpoonIcon(size: 18, color: AppColors.primary),
                    label: l.settingsSpoon,
                    value: 'spoon',
                    ctrl: _spoonLengthCtrl,
                    onLengthChanged: (v) { setState(() => _spoonLengthCm = v); _savePrefs(); },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionHeader(l.settingsDailyGoal),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(l.settingsGoalKcal),
                  const Spacer(),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      controller: _dailyGoalCtrl,
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
          _SectionHeader(l.settingsAiModel),
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
                        child: Text(l.settingsActive,
                            style: const TextStyle(color: Colors.green, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _apiKeyCtrl,
                    obscureText: _obscureKey,
                    decoration: InputDecoration(
                      labelText: l.settingsApiKeyLabel,
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
                          : Text(l.settingsSaveKey),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _SectionHeader(l.settingsStorage),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<String>(
                    future: _storageFuture,
                    builder: (context, snap) => Text(
                      snap.data ?? l.settingsCalculating,
                      style: const TextStyle(color: AppColors.subtle),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _exportCsv,
                    icon: const Icon(Icons.ios_share),
                    label: Text(l.settingsExportCsv),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _createBackup,
                    icon: const Icon(Icons.backup_outlined),
                    label: Text(l.settingsCreateBackup),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _restoreBackup,
                    icon: const Icon(Icons.restore_outlined),
                    label: Text(l.settingsRestoreBackup),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _clearHistory,
                    icon: const Icon(Icons.delete_forever, color: AppColors.error),
                    label: Text(l.settingsClearHistory,
                        style: const TextStyle(color: AppColors.error)),
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
    final l = AppLocalizations.of(context);
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
                TextSpan(text: l.settingsApiKeyHintPrefix),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: () => launchUrl(_url, mode: LaunchMode.externalApplication),
                    child: Text(
                      l.settingsGoogleAiStudio,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                TextSpan(text: l.settingsApiKeyHintSuffix),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _UtensilTile extends StatelessWidget {
  final Widget icon;
  final String label;
  final String value;
  final TextEditingController ctrl;
  final ValueChanged<double> onLengthChanged;

  const _UtensilTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.ctrl,
    required this.onLengthChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(
      value: value,
      title: Row(children: [
        SizedBox(width: 22, child: Center(child: icon)),
        const SizedBox(width: 10),
        Text(label),
      ]),
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
