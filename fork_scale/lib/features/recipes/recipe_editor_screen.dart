import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/decimal_input_formatter.dart';
import '../../l10n/app_localizations.dart';
import '../../models/recipe.dart';
import '../../models/recipe_item.dart';

class RecipeEditorScreen extends ConsumerStatefulWidget {
  final Recipe? existing;
  // When opened from BarcodeResultScreen: pre-populate one ingredient
  final Map<String, dynamic>? prefill;

  const RecipeEditorScreen({super.key, this.existing, this.prefill});

  @override
  ConsumerState<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends ConsumerState<RecipeEditorScreen>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _yieldCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _photoPath;
  late List<RecipeItem> _items;
  String? _yieldError;
  bool _saving = false;
  double _multiplier = 1.0;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl.text = e?.name ?? '';
    _yieldCtrl.text = e != null ? e.yieldG.toStringAsFixed(0) : '';
    _notesCtrl.text = e?.notes ?? '';
    _photoPath = e?.photoPath;
    _items = e?.items
            .map((i) => i.copyWith(id: null, recipeId: null))
            .toList() ??
        [];

    // Pre-fill from barcode result if provided
    final pf = widget.prefill;
    if (pf != null) {
      _items.add(RecipeItem(
        name: pf['prefillName'] as String? ?? '',
        weightG: (pf['prefillAmount'] as double?) ?? 100.0,
        kcalPer100g: (pf['prefillKcal'] as double?) ?? 0.0,
        totalKcal: ((pf['prefillAmount'] as double?) ?? 100.0) /
            100 *
            ((pf['prefillKcal'] as double?) ?? 0.0),
        source: 'off',
        barcode: pf['prefillBarcode'] as String?,
        proteinPer100g: pf['prefillProtein'] as double?,
        carbsPer100g: pf['prefillCarbs'] as double?,
        fatPer100g: pf['prefillFat'] as double?,
      ));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _yieldCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _yieldG => double.tryParse(_yieldCtrl.text) ?? 0;
  double get _sumKcal => _items.fold(0.0, (s, i) => s + i.totalKcal);
  double get _kcalPer100g => Recipe.computeKcalPer100g(_items, _yieldG);

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: source);
    if (xfile == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dest = p.join(dir.path, 'meal_photos', '${const Uuid().v4()}.jpg');
    await Directory(p.dirname(dest)).create(recursive: true);
    await File(xfile.path).copy(dest);
    setState(() => _photoPath = dest);
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.editorNameRequired)));
      return;
    }
    if (_yieldG <= 0) {
      setState(() => _yieldError = l.editorYieldError);
      return;
    }
    setState(() { _yieldError = null; _saving = true; });
    try {
      final now = DateTime.now();
      final kcal100 = Recipe.computeKcalPer100g(_items, _yieldG);
      final repo = ref.read(recipesRepositoryProvider);
      if (widget.existing == null) {
        final recipe = Recipe(
          name: name,
          yieldG: _yieldG,
          kcalPer100g: kcal100,
          photoPath: _photoPath,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          createdAt: now,
          updatedAt: now,
          items: _items,
        );
        await repo.insertRecipe(recipe);
      } else {
        final updated = widget.existing!.copyWith(
          name: name,
          yieldG: _yieldG,
          kcalPer100g: kcal100,
          photoPath: _photoPath,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          updatedAt: now,
          items: _items,
        );
        await repo.updateRecipe(updated);
      }
      if (!mounted) return;
      context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _applyMultiplier(double target) {
    if (target == _multiplier) return;
    final ratio = target / _multiplier;
    final newYield = _yieldG * ratio;
    setState(() {
      _multiplier = target;
      _items = _items
          .map((i) => i.copyWith(
                weightG: i.weightG * ratio,
                totalKcal: i.totalKcal * ratio,
              ))
          .toList();
      _yieldCtrl.text = newYield.toStringAsFixed(0);
    });
  }

  void _addIngredient({
    String? name,
    double? kcalPer100g,
    double? weightG,
    String? source,
    String? barcode,
    double? proteinPer100g,
    double? carbsPer100g,
    double? fatPer100g,
  }) {
    final w = weightG ?? 100.0;
    setState(() {
      _items.add(RecipeItem(
        name: name ?? '',
        weightG: w,
        kcalPer100g: kcalPer100g ?? 0,
        totalKcal: w / 100 * (kcalPer100g ?? 0),
        source: source ?? 'manual',
        barcode: barcode,
        proteinPer100g: proteinPer100g,
        carbsPer100g: carbsPer100g,
        fatPer100g: fatPer100g,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isNew = widget.existing == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? l.recipesNew : l.mealDetailEditRecipe),
        leading: BackButton(onPressed: () => context.pop()),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(l.actionSave,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Photo
                _PhotoPicker(path: _photoPath, onPick: _pickPhoto),
                const SizedBox(height: 16),
                // Name
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(labelText: l.editorRecipeName),
                ),
                const SizedBox(height: 12),
                // Yield
                TextField(
                  controller: _yieldCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: const [DecimalInputFormatter()],
                  decoration: InputDecoration(
                    labelText: l.editorYieldLabel,
                    hintText: l.editorYieldHint,
                    suffixText: 'g',
                    errorText: _yieldError,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                // Notes
                TextField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(labelText: l.resultsNotesLabel),
                ),
                const SizedBox(height: 16),
                // Scale multiplier chips
                Row(
                  children: [
                    Text(
                      l.editorScale,
                      style: const TextStyle(color: AppColors.subtle, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    for (final m in [0.5, 1.0, 2.0, 3.0, 4.0])
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: ChoiceChip(
                          label: Text(
                            m == 0.5
                                ? '×½'
                                : m == 1.0
                                    ? '×1'
                                    : '×${m.toInt()}',
                          ),
                          selected: _multiplier == m,
                          onSelected: (_) => _applyMultiplier(m),
                          selectedColor:
                              AppColors.primary.withValues(alpha: 0.2),
                          checkmarkColor: AppColors.primary,
                          showCheckmark: false,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                // Ingredient list
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l.mealDetailIngredients,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: () => _showAddIngredientSheet(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l.actionAdd),
                    ),
                  ],
                ),
                ..._items.asMap().entries.map((e) => _IngredientRow(
                      index: e.key,
                      item: e.value,
                      onChanged: (updated) => setState(
                          () => _items[e.key] = updated),
                      onDelete: () =>
                          setState(() => _items.removeAt(e.key)),
                    )),
                if (_items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(l.editorNoIngredients,
                          style: const TextStyle(color: AppColors.subtle)),
                    ),
                  ),
                const SizedBox(height: 80),
              ],
            ),
          ),
          // Sticky summary bar
          _SummaryBar(sumKcal: _sumKcal, kcalPer100g: _kcalPer100g, yieldG: _yieldG),
        ],
      ),
    );
  }

  Future<void> _showAddIngredientSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddIngredientSheet(
        onSelectSfcd: (r) {
          Navigator.pop(context);
          _addIngredient(
            name: r.name,
            kcalPer100g: r.kcalPer100g,
            source: 'swiss_fcd',
            proteinPer100g: r.proteinPer100g,
            carbsPer100g: r.carbsPer100g,
            fatPer100g: r.fatPer100g,
          );
        },
        onScanBarcode: () {
          Navigator.pop(context);
          context.push<Map<String, dynamic>?>('/scan', extra: {'forRecipe': true}).then((result) {
            if (result != null && mounted) {
              _addIngredient(
                name: result['name'] as String?,
                kcalPer100g: result['kcalPer100g'] as double?,
                weightG: result['weightG'] as double?,
                source: 'off',
                barcode: result['barcode'] as String?,
                proteinPer100g: result['proteinPer100g'] as double?,
                carbsPer100g: result['carbsPer100g'] as double?,
                fatPer100g: result['fatPer100g'] as double?,
              );
            }
          });
        },
        onManual: () {
          Navigator.pop(context);
          _addIngredient();
        },
      ),
    );
  }
}

// ── Ingredient row ────────────────────────────────────────────────────────────

class _IngredientRow extends StatefulWidget {
  final int index;
  final RecipeItem item;
  final ValueChanged<RecipeItem> onChanged;
  final VoidCallback onDelete;

  const _IngredientRow({
    required this.index,
    required this.item,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_IngredientRow> createState() => _IngredientRowState();
}

class _IngredientRowState extends State<_IngredientRow> {
  late TextEditingController _nameCtrl;
  late TextEditingController _weightCtrl;
  late TextEditingController _kcalCtrl;
  late TextEditingController _proteinCtrl;
  late TextEditingController _carbsCtrl;
  late TextEditingController _fatCtrl;
  late bool _macrosExpanded;

  static String _fmt(double? v) =>
      v == null ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString());

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _weightCtrl =
        TextEditingController(text: widget.item.weightG.toStringAsFixed(0));
    _kcalCtrl =
        TextEditingController(text: widget.item.kcalPer100g.toStringAsFixed(0));
    _proteinCtrl = TextEditingController(text: _fmt(widget.item.proteinPer100g));
    _carbsCtrl = TextEditingController(text: _fmt(widget.item.carbsPer100g));
    _fatCtrl = TextEditingController(text: _fmt(widget.item.fatPer100g));
    // Auto-expand when any macro is already known (e.g. after a barcode scan).
    _macrosExpanded = widget.item.proteinPer100g != null ||
        widget.item.carbsPer100g != null ||
        widget.item.fatPer100g != null;
  }

  @override
  void didUpdateWidget(_IngredientRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.weightG != widget.item.weightG) {
      _weightCtrl.text = widget.item.weightG.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _weightCtrl.dispose();
    _kcalCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    super.dispose();
  }

  RecipeItem get _cur => widget.item;

  void _emit(RecipeItem updated) => widget.onChanged(updated);

  // Rebuilds the item from the macro controllers. Built explicitly (not via
  // copyWith) so a cleared field becomes null ("unknown") rather than sticking
  // to the previous value.
  void _emitMacros() {
    _emit(RecipeItem(
      id: _cur.id,
      recipeId: _cur.recipeId,
      name: _cur.name,
      weightG: _cur.weightG,
      kcalPer100g: _cur.kcalPer100g,
      totalKcal: _cur.totalKcal,
      source: _cur.source,
      barcode: _cur.barcode,
      sortOrder: _cur.sortOrder,
      proteinPer100g: double.tryParse(_proteinCtrl.text),
      carbsPer100g: double.tryParse(_carbsCtrl.text),
      fatPer100g: double.tryParse(_fatCtrl.text),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    const sourceBadge = {
      'off': 'OFF',
      'swiss_fcd': 'SFCD',
      'manual': '',
    };
    final badge = sourceBadge[_cur.source] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: l.editorIngredientLabel,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  onChanged: (v) => _emit(_cur.copyWith(name: v)),
                ),
              ),
              if (badge.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(badge,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.primary)),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                onPressed: widget.onDelete,
                visualDensity: VisualDensity.compact,
              ),
            ]),
            const Divider(height: 12),
            Row(children: [
              Expanded(
                child: _Field(
                  label: l.ingredientWeight,
                  controller: _weightCtrl,
                  onChanged: (v) {
                    final w = double.tryParse(v) ?? _cur.weightG;
                    _emit(_cur.copyWith(
                        weightG: w,
                        totalKcal: w / 100 * _cur.kcalPer100g));
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Field(
                  label: l.ingredientKcalPer100g,
                  controller: _kcalCtrl,
                  onChanged: (v) {
                    final k = double.tryParse(v) ?? _cur.kcalPer100g;
                    _emit(_cur.copyWith(
                        kcalPer100g: k,
                        totalKcal: _cur.weightG / 100 * k));
                  },
                ),
              ),
            ]),
            const SizedBox(height: 8),
            // Macros (per 100g) — collapsible, optional
            InkWell(
              onTap: () => setState(() => _macrosExpanded = !_macrosExpanded),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      _macrosExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      size: 18,
                      color: AppColors.subtle,
                    ),
                    const SizedBox(width: 2),
                    Text(l.ingredientMacros,
                        style: const TextStyle(fontSize: 12, color: AppColors.subtle)),
                  ],
                ),
              ),
            ),
            if (_macrosExpanded)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  Expanded(
                    child: _Field(
                      label: l.ingredientProtein,
                      controller: _proteinCtrl,
                      onChanged: (_) => _emitMacros(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Field(
                      label: l.ingredientCarbs,
                      controller: _carbsCtrl,
                      onChanged: (_) => _emitMacros(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Field(
                      label: l.ingredientFat,
                      controller: _fatCtrl,
                      onChanged: (_) => _emitMacros(),
                    ),
                  ),
                ]),
              ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                l.kcalValue(_cur.totalKcal.round()),
                style: const TextStyle(
                    color: AppColors.accent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _Field(
      {required this.label,
      required this.controller,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.subtle)),
        const SizedBox(height: 2),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: const [DecimalInputFormatter()],
        ),
      ],
    );
  }
}

// ── Photo picker ──────────────────────────────────────────────────────────────

class _PhotoPicker extends StatelessWidget {
  final String? path;
  final Future<void> Function(ImageSource) onPick;
  const _PhotoPicker({required this.path, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPickerMenu(context),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2), width: 1.5),
        ),
        child: path != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.file(
                  File(path!),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  cacheWidth: 800,
                  errorBuilder: (_, _, _) => const _PhotoPlaceholder(),
                ))
            : const _PhotoPlaceholder(),
      ),
    );
  }

  void _showPickerMenu(BuildContext context) {
    final l = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(l.captureTakePhoto),
              onTap: () {
                Navigator.pop(context);
                onPick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(l.editorChooseGallery),
              onTap: () {
                Navigator.pop(context);
                onPick(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.add_photo_alternate_outlined, size: 36, color: AppColors.primary),
        const SizedBox(height: 8),
        Text(AppLocalizations.of(context).editorAddPhoto,
            style: const TextStyle(color: AppColors.subtle, fontSize: 13)),
      ],
    );
  }
}

// ── Summary bar ───────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final double sumKcal;
  final double kcalPer100g;
  final double yieldG;
  const _SummaryBar(
      {required this.sumKcal,
      required this.kcalPer100g,
      required this.yieldG});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l.editorTotalKcal(sumKcal.round()),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
          Text(
            yieldG > 0
                ? l.editorPer100(kcalPer100g.round())
                : l.editorPer100Unknown,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

// ── Add ingredient sheet ──────────────────────────────────────────────────────

class _SfcdResult {
  final String name;
  final double kcalPer100g;
  final double? proteinPer100g;
  final double? carbsPer100g;
  final double? fatPer100g;
  const _SfcdResult({
    required this.name,
    required this.kcalPer100g,
    this.proteinPer100g,
    this.carbsPer100g,
    this.fatPer100g,
  });
}

class _AddIngredientSheet extends ConsumerStatefulWidget {
  final void Function(_SfcdResult result) onSelectSfcd;
  final VoidCallback onScanBarcode;
  final VoidCallback onManual;

  const _AddIngredientSheet({
    required this.onSelectSfcd,
    required this.onScanBarcode,
    required this.onManual,
  });

  @override
  ConsumerState<_AddIngredientSheet> createState() => _AddIngredientSheetState();
}

class _AddIngredientSheetState extends ConsumerState<_AddIngredientSheet> {
  final _searchCtrl = TextEditingController();
  List<_SfcdResult> _results = [];
  bool _searching = false;
  Timer? _debounce;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() { _results = []; _searching = false; });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final sfcdResults = await ref.read(sfcdServiceProvider).search(q.trim());
      if (!mounted) return;
      setState(() {
        _results = sfcdResults
            .map((r) => _SfcdResult(
                  name: r.name,
                  kcalPer100g: r.kcalPer100g,
                  proteinPer100g: r.proteinPer100g,
                  carbsPer100g: r.carbsPer100g,
                  fatPer100g: r.fatPer100g,
                ))
            .toList();
        _searching = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: _onQueryChanged,
                decoration: InputDecoration(
                  hintText: l.editorSearchHint,
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),
            if (_searching)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )
            else if (_results.isNotEmpty)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (_, i) {
                    final r = _results[i];
                    return ListTile(
                      title: Text(r.name),
                      trailing: Text(l.recipeKcalPer100g(r.kcalPer100g.round()),
                          style: const TextStyle(color: AppColors.subtle)),
                      onTap: () => widget.onSelectSfcd(r),
                    );
                  },
                ),
              )
            else if (_searchCtrl.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l.editorNoResults,
                    style: const TextStyle(color: AppColors.subtle)),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: Text(l.captureScanBarcode),
              onTap: widget.onScanBarcode,
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l.barcodeEnterManually),
              onTap: widget.onManual,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
