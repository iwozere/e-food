import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/providers.dart';
import '../../core/theme/app_theme.dart';
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
  final _searchCtrl = TextEditingController();
  String? _photoPath;
  late List<RecipeItem> _items;
  String? _yieldError;
  bool _saving = false;
  double _multiplier = 1.0;
  List<_SfcdResult> _searchResults = [];
  bool _searching = false;

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
      ));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _yieldCtrl.dispose();
    _notesCtrl.dispose();
    _searchCtrl.dispose();
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
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Recipe name is required')));
      return;
    }
    if (_yieldG <= 0) {
      setState(() => _yieldError = 'Yield must be greater than 0');
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

  Future<void> _searchSfcd(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    final results = await ref.read(sfcdServiceProvider).search(query);
    if (mounted) {
      setState(() {
        _searchResults = results
            .map((r) => _SfcdResult(name: r.name, kcalPer100g: r.kcalPer100g))
            .toList();
        _searching = false;
      });
    }
  }

  void _addIngredient({String? name, double? kcalPer100g, double? weightG, String? source, String? barcode}) {
    final w = weightG ?? 100.0;
    setState(() {
      _items.add(RecipeItem(
        name: name ?? '',
        weightG: w,
        kcalPer100g: kcalPer100g ?? 0,
        totalKcal: w / 100 * (kcalPer100g ?? 0),
        source: source ?? 'manual',
        barcode: barcode,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'New recipe' : 'Edit recipe'),
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
                : const Text('Save',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  decoration: const InputDecoration(labelText: 'Recipe name *'),
                ),
                const SizedBox(height: 12),
                // Yield
                TextField(
                  controller: _yieldCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                  ],
                  decoration: InputDecoration(
                    labelText: 'Yield (g) *',
                    hintText: 'Total grams produced',
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
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
                ),
                const SizedBox(height: 16),
                // Scale multiplier chips
                Row(
                  children: [
                    const Text(
                      'Scale',
                      style: TextStyle(color: AppColors.subtle, fontSize: 13),
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
                    const Text('Ingredients',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: () => _showAddIngredientSheet(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
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
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text('No ingredients yet',
                          style: TextStyle(color: AppColors.subtle)),
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
        searchCtrl: _searchCtrl,
        searchResults: _searchResults,
        searching: _searching,
        onSearch: _searchSfcd,
        onSelectSfcd: (name, kcal) {
          Navigator.pop(context);
          _addIngredient(name: name, kcalPer100g: kcal, source: 'swiss_fcd');
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

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _weightCtrl =
        TextEditingController(text: widget.item.weightG.toStringAsFixed(0));
    _kcalCtrl =
        TextEditingController(text: widget.item.kcalPer100g.toStringAsFixed(0));
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
    super.dispose();
  }

  RecipeItem get _cur => widget.item;

  void _emit(RecipeItem updated) => widget.onChanged(updated);

  @override
  Widget build(BuildContext context) {
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
                  decoration: const InputDecoration(
                    labelText: 'Ingredient',
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
                  label: 'Weight (g)',
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
                  label: 'kcal/100g',
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
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_cur.totalKcal.round()} kcal',
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
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
          ],
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
        child: path != null && File(path!).existsSync()
            ? ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image.file(File(path!), fit: BoxFit.cover,
                    width: double.infinity))
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 36, color: AppColors.primary),
                  SizedBox(height: 8),
                  Text('Add photo (optional)',
                      style:
                          TextStyle(color: AppColors.subtle, fontSize: 13)),
                ],
              ),
      ),
    );
  }

  void _showPickerMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(context);
                onPick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
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
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total: ${sumKcal.round()} kcal',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
          Text(
            yieldG > 0
                ? 'Per 100g: ${kcalPer100g.round()} kcal'
                : 'Per 100g: — kcal',
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
  const _SfcdResult({required this.name, required this.kcalPer100g});
}

class _AddIngredientSheet extends StatelessWidget {
  final TextEditingController searchCtrl;
  final List<_SfcdResult> searchResults;
  final bool searching;
  final ValueChanged<String> onSearch;
  final void Function(String name, double kcal) onSelectSfcd;
  final VoidCallback onScanBarcode;
  final VoidCallback onManual;

  const _AddIngredientSheet({
    required this.searchCtrl,
    required this.searchResults,
    required this.searching,
    required this.onSearch,
    required this.onSelectSfcd,
    required this.onScanBarcode,
    required this.onManual,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7),
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
                controller: searchCtrl,
                autofocus: true,
                onChanged: onSearch,
                decoration: const InputDecoration(
                  hintText: 'Search food database…',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            if (searching)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )
            else if (searchResults.isNotEmpty)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: searchResults.length,
                  itemBuilder: (_, i) {
                    final r = searchResults[i];
                    return ListTile(
                      title: Text(r.name),
                      trailing: Text('${r.kcalPer100g.round()} kcal/100g',
                          style: const TextStyle(color: AppColors.subtle)),
                      onTap: () => onSelectSfcd(r.name, r.kcalPer100g),
                    );
                  },
                ),
              )
            else if (searchCtrl.text.isNotEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No results found',
                    style: TextStyle(color: AppColors.subtle)),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('Scan barcode'),
              onTap: onScanBarcode,
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Enter manually'),
              onTap: onManual,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
