import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/open_food_facts_service.dart';
import '../../core/services/providers.dart';
import '../../core/theme/app_theme.dart';
import '../history/history_providers.dart';
import '../../models/cached_product.dart';
import '../../models/meal.dart';
import '../../models/meal_item.dart';

class BarcodeResultScreen extends ConsumerStatefulWidget {
  final String barcode;
  final bool forRecipe;
  const BarcodeResultScreen({super.key, required this.barcode, this.forRecipe = false});

  @override
  ConsumerState<BarcodeResultScreen> createState() =>
      _BarcodeResultScreenState();
}

class _BarcodeResultScreenState extends ConsumerState<BarcodeResultScreen> {
  CachedProduct? _product;
  bool _loading = true;
  String? _errorMsg;

  // editable fields
  late TextEditingController _nameCtrl;
  late TextEditingController _kcalCtrl;
  late TextEditingController _amountCtrl;
  double _amount = 100;
  String? _mealType;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _kcalCtrl = TextEditingController();
    _amountCtrl = TextEditingController(text: '100');
    _mealType = Meal.detectTypeFromTime();
    _lookup();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _kcalCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final products = ref.read(productsRepositoryProvider);
    final off = ref.read(offServiceProvider);

    // Step 1: local cache
    var product = await products.getByBarcode(widget.barcode);
    if (product == null) {
      // Step 2: Open Food Facts
      try {
        product = await off.lookup(widget.barcode);
        await products.upsert(product);
      } on OffProductNotFoundException {
        if (mounted) setState(() { _loading = false; _errorMsg = 'not_found'; });
        return;
      } on OffServiceException {
        if (mounted) setState(() { _loading = false; _errorMsg = 'service_error'; });
        return;
      } catch (_) {
        if (mounted) setState(() { _loading = false; _errorMsg = 'service_error'; });
        return;
      }
    }

    if (!mounted) return;
    final defaultAmount = product.packSizeG ?? 100.0;
    setState(() {
      _product = product;
      _loading = false;
      _amount = defaultAmount;
      _nameCtrl.text = product!.name;
      _kcalCtrl.text = product.kcalPer100g.toStringAsFixed(0);
      _amountCtrl.text = defaultAmount.toStringAsFixed(0);
    });
  }

  double get _totalKcal {
    final kcal = double.tryParse(_kcalCtrl.text) ?? (_product?.kcalPer100g ?? 0);
    return _amount / 100 * kcal;
  }

  void _stepAmount(int delta) {
    final newVal = (_amount + delta).clamp(0, 9999).toDouble();
    setState(() {
      _amount = newVal;
      _amountCtrl.text = newVal.toStringAsFixed(0);
    });
  }

  Future<void> _logMeal() async {
    final p = _product;
    if (p == null) return;
    final kcalPer100 = double.tryParse(_kcalCtrl.text) ?? p.kcalPer100g;
    final total = _amount / 100 * kcalPer100;
    final meal = Meal(
      createdAt: DateTime.now(),
      photoPath: '',
      name: _nameCtrl.text.trim(),
      totalKcal: total,
      utensil: 'fork',
      modelUsed: 'barcode',
      mealType: _mealType,
      source: 'barcode',
      barcode: widget.barcode,
      items: [
        MealItem(
          name: _nameCtrl.text.trim(),
          weightG: _amount,
          kcalPer100g: kcalPer100,
          totalKcal: total,
        ),
      ],
    );
    await ref.read(mealsRepositoryProvider).insertMeal(meal);
    if (!mounted) return;
    ref.invalidate(historyMealsProvider);
    ref.invalidate(historyDayTotalProvider);
    ref.invalidate(historyWeeklyKcalProvider);
    context.go('/history');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_nameCtrl.text} logged (${total.round()} kcal)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('Barcode: ${widget.barcode}')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMsg != null) {
      return _NotFoundScreen(barcode: widget.barcode, isTimeout: _errorMsg == 'service_error', forRecipe: widget.forRecipe);
    }

    final p = _product!;

    return Scaffold(
      appBar: AppBar(title: Text(p.brand ?? 'Product')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Product image
          if (p.imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: p.imageUrl!,
                height: 180,
                fit: BoxFit.contain,
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          const SizedBox(height: 16),
          // Name & brand row
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: 'Product name',
              suffix: p.brand != null
                  ? Text(p.brand!,
                      style: const TextStyle(color: AppColors.subtle, fontSize: 13))
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          // Pack size row
          Row(children: [
            Text('Pack: ${p.packSizeG != null ? "${p.packSizeG!.round()} g/ml" : "—"}',
                style: const TextStyle(color: AppColors.subtle)),
          ]),
          const SizedBox(height: 16),
          // Nutrition table
          _NutritionCard(product: p, kcalCtrl: _kcalCtrl, onKcalChanged: () => setState(() {})),
          const SizedBox(height: 16),
          // Amount stepper
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('How much did you have?',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () => _stepAmount(-10),
                        icon: const Icon(Icons.remove_circle_outline),
                        color: AppColors.primary,
                      ),
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: _amountCtrl,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: InputDecoration(
                            suffixText: p.packSizeG != null ? 'ml/g' : 'g',
                          ),
                          onChanged: (v) {
                            setState(() => _amount = double.tryParse(v) ?? _amount);
                          },
                        ),
                      ),
                      IconButton(
                        onPressed: () => _stepAmount(10),
                        icon: const Icon(Icons.add_circle_outline),
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Total: ${_totalKcal.round()} kcal',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Meal type
          _MealTypeChips(
            current: _mealType,
            onChanged: (t) => setState(() => _mealType = t),
          ),
          const SizedBox(height: 24),
          // Actions
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _logMeal,
                icon: const Icon(Icons.check),
                label: const Text('Log this meal'),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () {
                final kcalPer100 = double.tryParse(_kcalCtrl.text) ?? p.kcalPer100g;
                if (widget.forRecipe) {
                  context.pop(<String, dynamic>{
                    'name': _nameCtrl.text.trim(),
                    'kcalPer100g': kcalPer100,
                    'weightG': _amount,
                    'barcode': widget.barcode,
                  });
                } else {
                  context.push('/recipes/new', extra: {
                    'prefillName': _nameCtrl.text,
                    'prefillKcal': kcalPer100,
                    'prefillAmount': _amount,
                    'prefillBarcode': widget.barcode,
                  });
                }
              },
              icon: const Icon(Icons.menu_book),
              label: const Text('Add to recipe'),
            ),
          ]),
          if (!widget.forRecipe) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final kcalPer100 = double.tryParse(_kcalCtrl.text) ?? p.kcalPer100g;
                  context.push('/barcode-meal-builder', extra: <String, dynamic>{
                    'name': _nameCtrl.text.trim(),
                    'kcalPer100g': kcalPer100,
                    'weightG': _amount,
                    'barcode': widget.barcode,
                    'mealType': _mealType,
                  });
                },
                icon: const Icon(Icons.playlist_add),
                label: const Text('Add more items'),
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _NutritionCard extends StatelessWidget {
  final CachedProduct product;
  final TextEditingController kcalCtrl;
  final VoidCallback onKcalChanged;

  const _NutritionCard({
    required this.product,
    required this.kcalCtrl,
    required this.onKcalChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nutrition per 100 g / 100 ml',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(children: [
              const Expanded(child: Text('Energy (kcal)')),
              SizedBox(
                width: 90,
                child: TextField(
                  controller: kcalCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(suffixText: 'kcal'),
                  onChanged: (_) => onKcalChanged(),
                ),
              ),
            ]),
            if (product.proteinG != null) _Row('Protein', product.proteinG!, 'g'),
            if (product.carbsG != null) _Row('Carbs', product.carbsG!, 'g'),
            if (product.fatG != null) _Row('Fat', product.fatG!, 'g'),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  const _Row(this.label, this.value, this.unit);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(color: AppColors.subtle))),
        Text('${value.toStringAsFixed(1)} $unit',
            style: const TextStyle(color: AppColors.subtle)),
      ]),
    );
  }
}

class _MealTypeChips extends StatelessWidget {
  final String? current;
  final ValueChanged<String> onChanged;
  const _MealTypeChips({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const types = ['breakfast', 'lunch', 'snack', 'dinner'];
    const labels = {'breakfast': 'Breakfast', 'lunch': 'Lunch', 'snack': 'Snack', 'dinner': 'Dinner'};
    return Wrap(
      spacing: 8,
      children: types
          .map((t) => ChoiceChip(
                label: Text(labels[t]!),
                selected: current == t,
                onSelected: (_) => onChanged(t),
                selectedColor: AppColors.accent.withValues(alpha: 0.2),
              ))
          .toList(),
    );
  }
}

class _NotFoundScreen extends ConsumerStatefulWidget {
  final String barcode;
  final bool isTimeout;
  final bool forRecipe;
  const _NotFoundScreen({required this.barcode, required this.isTimeout, this.forRecipe = false});

  @override
  ConsumerState<_NotFoundScreen> createState() => _NotFoundScreenState();
}

class _NotFoundScreenState extends ConsumerState<_NotFoundScreen> {
  bool _showForm = false;

  // manual-entry form state
  final _nameCtrl = TextEditingController();
  final _kcalCtrl = TextEditingController();
  final _amountCtrl = TextEditingController(text: '100');
  double _amount = 100;
  String _mealType = Meal.detectTypeFromTime();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _kcalCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  double get _totalKcal {
    final k = double.tryParse(_kcalCtrl.text) ?? 0;
    return _amount / 100 * k;
  }

  Future<void> _openContribute() async {
    final uri = Uri.parse(
        'https://world.openfoodfacts.org/product/${widget.barcode}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _stepAmount(int delta) {
    final v = (_amount + delta).clamp(0, 9999).toDouble();
    setState(() {
      _amount = v;
      _amountCtrl.text = v.toStringAsFixed(0);
    });
  }

  void _addToRecipe() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product name is required')),
      );
      return;
    }
    final kcal = double.tryParse(_kcalCtrl.text) ?? 0;
    context.pop(<String, dynamic>{
      'name': name,
      'kcalPer100g': kcal,
      'weightG': _amount,
      'barcode': widget.barcode,
    });
  }

  Future<void> _logManual() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product name is required')),
      );
      return;
    }
    final kcal = double.tryParse(_kcalCtrl.text) ?? 0;
    final total = _amount / 100 * kcal;
    setState(() => _saving = true);
    try {
      await ref.read(mealsRepositoryProvider).insertMeal(Meal(
        createdAt: DateTime.now(),
        photoPath: '',
        name: name,
        totalKcal: total,
        utensil: 'fork',
        modelUsed: 'barcode',
        mealType: _mealType,
        source: 'barcode',
        barcode: widget.barcode,
        items: [
          MealItem(
            name: name,
            weightG: _amount,
            kcalPer100g: kcal,
            totalKcal: total,
          ),
        ],
      ));
      if (!mounted) return;
      ref.invalidate(historyMealsProvider);
      ref.invalidate(historyDayTotalProvider);
      ref.invalidate(historyWeeklyKcalProvider);
      context.go('/history');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showForm ? 'Enter manually' : 'Product not found'),
        leading: _showForm
            ? BackButton(onPressed: () => setState(() => _showForm = false))
            : null,
      ),
      body: _showForm ? _buildForm() : _buildNotFound(),
    );
  }

  Widget _buildNotFound() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.search_off, size: 64, color: AppColors.subtle),
          const SizedBox(height: 16),
          Text(
            widget.isTimeout
                ? 'Could not reach product database.'
                : 'No product found for barcode ${widget.barcode}.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.subtle),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _openContribute,
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Contribute to Open Food Facts'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => setState(() => _showForm = true),
            icon: const Icon(Icons.edit),
            label: const Text('Enter manually'),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Barcode: ${widget.barcode}',
          style: const TextStyle(color: AppColors.subtle, fontSize: 12),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Product name *'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _kcalCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'kcal per 100 g',
            suffixText: 'kcal',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        const Text('How much did you have?',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () => _stepAmount(-10),
              icon: const Icon(Icons.remove_circle_outline),
              color: AppColors.primary,
            ),
            SizedBox(
              width: 90,
              child: TextField(
                controller: _amountCtrl,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(suffixText: 'g'),
                onChanged: (v) =>
                    setState(() => _amount = double.tryParse(v) ?? _amount),
              ),
            ),
            IconButton(
              onPressed: () => _stepAmount(10),
              icon: const Icon(Icons.add_circle_outline),
              color: AppColors.primary,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Total: ${_totalKcal.round()} kcal',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.accent,
            ),
          ),
        ),
        if (!widget.forRecipe) ...[
          const SizedBox(height: 16),
          _MealTypeChips(
            current: _mealType,
            onChanged: (t) => setState(() => _mealType = t),
          ),
        ],
        const SizedBox(height: 24),
        if (widget.forRecipe)
          FilledButton.icon(
            onPressed: _addToRecipe,
            icon: const Icon(Icons.menu_book),
            label: const Text('Add to recipe'),
          )
        else
          FilledButton.icon(
            onPressed: _saving ? null : _logManual,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('Log this meal'),
          ),
      ],
    );
  }
}
