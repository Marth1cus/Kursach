import 'package:flutter/material.dart';

import '../models/shoe.dart';
import '../models/shoe_filter.dart';
import '../styles/app_styles.dart';
import '../widgets/common.dart';

/// Панель фильтров каталога. Использует несколько видов селекторов:
/// SegmentedButton (пол), RadioListTile (категория), CheckboxListTile (бренды),
/// RangeSlider (цена), ChoiceChip (размер), SwitchListTile (наличие, скидка).
class FilterSheet extends StatefulWidget {
  final ShoeFilter initial;
  final CatalogMeta meta;
  const FilterSheet({super.key, required this.initial, required this.meta});

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late String? _gender = widget.initial.gender;
  late String? _category = widget.initial.category;
  late final Set<String> _brands = {...widget.initial.brands};
  late RangeValues _price = RangeValues(
    (widget.initial.minPrice ?? widget.meta.minPrice).toDouble().clamp(_min, _max),
    (widget.initial.maxPrice ?? widget.meta.maxPrice).toDouble().clamp(_min, _max),
  );
  late String? _size = widget.initial.size;
  late bool _inStock = widget.initial.inStockOnly;
  late bool _sale = widget.initial.saleOnly;

  double get _min => (widget.meta.minPrice ~/ 1000 * 1000).toDouble();
  double get _max {
    final m = ((widget.meta.maxPrice + 999) ~/ 1000 * 1000).toDouble();
    return m <= _min ? _min + 1000 : m;
  }

  bool get _priceChanged => _price.start > _min || _price.end < _max;

  void _reset() => setState(() {
    _gender = null;
    _category = null;
    _brands.clear();
    _price = RangeValues(_min, _max);
    _size = null;
    _inStock = false;
    _sale = false;
  });

  void _apply() {
    Navigator.pop(
      context,
      widget.initial.copyWith(
        gender: () => _gender,
        category: () => _category,
        brands: {..._brands},
        minPrice: () => _priceChanged ? _price.start.round() : null,
        maxPrice: () => _priceChanged ? _price.end.round() : null,
        size: () => _size,
        inStockOnly: _inStock,
        saleOnly: _sale,
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(0, AppStyles.gapL, 0, AppStyles.gapS),
    child: Text(title, style: AppStyles.sectionTitle),
  );

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final tileWidth = width > 600 ? 220.0 : (width - 48) / 2;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppStyles.gapL),
            child: Row(
              children: [
                const Text('Фильтры', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const Spacer(),
                TextButton(onPressed: _reset, child: const Text('Сбросить')),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.symmetric(horizontal: AppStyles.gapL),
              children: [
                _section('Для кого'),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('Все'), icon: Icon(Icons.people_alt_outlined)),
                    ButtonSegment(value: 'men', label: Text('Мужчинам'), icon: Icon(Icons.man_rounded)),
                    ButtonSegment(value: 'women', label: Text('Женщинам'), icon: Icon(Icons.woman_rounded)),
                  ],
                  selected: {_gender ?? 'all'},
                  onSelectionChanged: (v) => setState(() => _gender = v.first == 'all' ? null : v.first),
                ),

                _section('Вид спорта'),
                RadioGroup<String>(
                  groupValue: _category ?? '',
                  onChanged: (v) => setState(() => _category = (v == null || v.isEmpty) ? null : v),
                  child: Wrap(
                    children: [
                      SizedBox(
                        width: tileWidth,
                        child: const RadioListTile<String>(value: '', title: Text('Все'), dense: true),
                      ),
                      for (final e in ShoeCategories.labels.entries)
                        SizedBox(
                          width: tileWidth,
                          child: RadioListTile<String>(
                            value: e.key,
                            dense: true,
                            title: Text(e.value),
                            secondary: Icon(ShoeCategories.icon(e.key), color: ShoeCategories.color(e.key)),
                          ),
                        ),
                    ],
                  ),
                ),

                _section('Бренд'),
                Wrap(
                  children: [
                    for (final b in widget.meta.brands)
                      SizedBox(
                        width: tileWidth,
                        child: CheckboxListTile(
                          value: _brands.contains(b),
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(b),
                          onChanged: (v) => setState(() => v! ? _brands.add(b) : _brands.remove(b)),
                        ),
                      ),
                  ],
                ),

                _section('Цена'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('от ${formatPrice(_price.start.round())}'),
                    Text('до ${formatPrice(_price.end.round())}'),
                  ],
                ),
                RangeSlider(
                  values: _price,
                  min: _min,
                  max: _max,
                  divisions: ((_max - _min) / 500).round().clamp(1, 200),
                  labels: RangeLabels(formatPrice(_price.start.round()), formatPrice(_price.end.round())),
                  onChanged: (v) => setState(() => _price = v),
                ),

                _section('Размер (EU)'),
                Wrap(
                  spacing: AppStyles.gapS,
                  runSpacing: AppStyles.gapS,
                  children: [
                    for (final s in widget.meta.sizes)
                      ChoiceChip(
                        label: Text(s),
                        selected: _size == s,
                        onSelected: (sel) => setState(() => _size = sel ? s : null),
                      ),
                  ],
                ),

                const SizedBox(height: AppStyles.gapL),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Только в наличии'),
                  secondary: const Icon(Icons.inventory_2_outlined),
                  value: _inStock,
                  onChanged: (v) => setState(() => _inStock = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Только со скидкой'),
                  secondary: const Icon(Icons.local_offer_outlined),
                  value: _sale,
                  onChanged: (v) => setState(() => _sale = v),
                ),
                const SizedBox(height: AppStyles.gapL),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppStyles.gapL),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _apply,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Применить'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
