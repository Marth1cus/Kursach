import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/shoe.dart';
import '../services/api_service.dart';
import '../styles/app_styles.dart';
import '../widgets/common.dart';
import '../widgets/shoe_image.dart';

/// Форма добавления и редактирования модели (только для администратора).
class ShoeFormScreen extends StatefulWidget {
  final Shoe? shoe;
  const ShoeFormScreen({super.key, this.shoe});

  @override
  State<ShoeFormScreen> createState() => _ShoeFormScreenState();
}

class _ShoeFormScreenState extends State<ShoeFormScreen> {
  static const List<String> allSizes = [
    '35',
    '36',
    '37',
    '38',
    '39',
    '40',
    '41',
    '42',
    '43',
    '44',
    '45',
    '46',
    '47',
    '48',
  ];

  final _formKey = GlobalKey<FormState>();
  late final Shoe _initial = widget.shoe ?? Shoe.empty();

  late final _name = TextEditingController(text: _initial.name);
  late final _brand = TextEditingController(text: _initial.brand);
  late final _price = TextEditingController(text: _initial.price > 0 ? '${_initial.price}' : '');
  late final _oldPrice = TextEditingController(text: _initial.oldPrice > 0 ? '${_initial.oldPrice}' : '');
  late final _color = TextEditingController(text: _initial.color);
  late final _material = TextEditingController(text: _initial.material);
  late final _surface = TextEditingController(text: _initial.surface);
  late final _weight = TextEditingController(text: _initial.weight > 0 ? '${_initial.weight}' : '');
  late final _description = TextEditingController(text: _initial.description);
  late final _imageUrl = TextEditingController(text: _initial.imageUrl);

  late String _category = _initial.category;
  late String _gender = _initial.gender;
  late final Set<String> _sizes = {..._initial.sizes};
  late bool _inStock = _initial.inStock;
  bool _saving = false;
  bool _dirty = false;

  bool get _isNew => _initial.isNew;

  @override
  void dispose() {
    for (final c in [_name, _brand, _price, _oldPrice, _color, _material, _surface, _weight, _description, _imageUrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      showMessage(context, 'Проверьте правильность заполнения полей', error: true);
      return;
    }
    if (_sizes.isEmpty) {
      showMessage(context, 'Выберите хотя бы один размер', error: true);
      return;
    }
    final shoe = Shoe(
      id: _initial.id,
      name: _name.text.trim(),
      brand: _brand.text.trim(),
      category: _category,
      gender: _gender,
      price: int.parse(_price.text),
      oldPrice: int.tryParse(_oldPrice.text) ?? 0,
      color: _color.text.trim(),
      sizes: _sizes.toList()..sort((a, b) => double.parse(a).compareTo(double.parse(b))),
      material: _material.text.trim(),
      surface: _surface.text.trim(),
      weight: int.tryParse(_weight.text) ?? 0,
      description: _description.text.trim(),
      imageUrl: _imageUrl.text.trim(),
      inStock: _inStock,
    );
    setState(() => _saving = true);
    try {
      final saved = await ApiService.instance.saveShoe(shoe);
      if (mounted) Navigator.pop(context, saved);
    } on ApiException catch (e) {
      if (mounted) showMessage(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    return confirmDialog(
      context,
      title: 'Выйти без сохранения?',
      message: 'Внесённые изменения будут потеряны.',
      confirmText: 'Выйти',
      destructive: true,
    );
  }

  String? _required(String? v, String label) => (v == null || v.trim().isEmpty) ? 'Заполните поле «$label»' : null;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) {
          _dirty = false;
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? 'Новая модель' : 'Редактирование'),
          actions: [
            TextButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Сохранить'),
            ),
            const SizedBox(width: AppStyles.gapS),
          ],
        ),
        body: Form(
          key: _formKey,
          onChanged: () => _dirty = true,
          child: ListView(
            padding: AppStyles.screenPadding,
            children: [
              ContentWidth(
                maxWidth: 720,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _imagePreview(),
                    const SizedBox(height: AppStyles.gapL),
                    TextFormField(
                      controller: _imageUrl,
                      decoration: AppStyles.input(
                        'Ссылка на изображение',
                        icon: Icons.image_outlined,
                        hint: 'https://… или /images/shoe_01.png',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppStyles.gapL),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _brand,
                            decoration: AppStyles.input('Бренд *', icon: Icons.sell_outlined),
                            validator: (v) => _required(v, 'Бренд'),
                          ),
                        ),
                        const SizedBox(width: AppStyles.gapM),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _name,
                            decoration: AppStyles.input('Название модели *'),
                            validator: (v) {
                              if (v == null || v.trim().length < 2) return 'Минимум 2 символа';
                              if (v.trim().length > 100) return 'Максимум 100 символов';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppStyles.gapL),
                    // Выпадающий список категорий
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: AppStyles.input('Вид спорта', icon: ShoeCategories.icon(_category)),
                      items: [
                        for (final e in ShoeCategories.labels.entries)
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ],
                      onChanged: (v) => setState(() {
                        _category = v!;
                        _dirty = true;
                      }),
                    ),
                    const SizedBox(height: AppStyles.gapL),

                    // Радиокнопки выбора пола
                    const Text('Для кого', style: AppStyles.sectionTitle),
                    RadioGroup<String>(
                      groupValue: _gender,
                      onChanged: (v) => setState(() {
                        _gender = v!;
                        _dirty = true;
                      }),
                      child: Wrap(
                        children: [
                          for (final e in Genders.labels.entries)
                            SizedBox(
                              width: 200,
                              child: RadioListTile<String>(value: e.key, title: Text(e.value), dense: true),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppStyles.gapS),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _price,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: AppStyles.input('Цена, ₽ *', icon: Icons.payments_outlined),
                            validator: (v) {
                              final p = int.tryParse(v ?? '');
                              if (p == null || p <= 0) return 'Укажите цену больше 0';
                              if (p > 1000000) return 'Не более 1 000 000 ₽';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: AppStyles.gapM),
                        Expanded(
                          child: TextFormField(
                            controller: _oldPrice,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: AppStyles.input('Цена до скидки, ₽', icon: Icons.local_offer_outlined),
                            validator: (v) {
                              final old = int.tryParse(v ?? '') ?? 0;
                              final price = int.tryParse(_price.text) ?? 0;
                              if (old != 0 && old <= price) return 'Должна быть больше цены';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppStyles.gapL),

                    // Размеры — множественный выбор (FilterChip)
                    Row(
                      children: [
                        const Text('Размеры в наличии *', style: AppStyles.sectionTitle),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setState(() {
                            _sizes.length == allSizes.length ? _sizes.clear() : _sizes.addAll(allSizes);
                            _dirty = true;
                          }),
                          child: Text(_sizes.length == allSizes.length ? 'Снять все' : 'Выбрать все'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppStyles.gapS),
                    Wrap(
                      spacing: AppStyles.gapS,
                      runSpacing: AppStyles.gapS,
                      children: [
                        for (final s in {...allSizes, ..._sizes})
                          FilterChip(
                            label: Text(s),
                            selected: _sizes.contains(s),
                            onSelected: (sel) => setState(() {
                              sel ? _sizes.add(s) : _sizes.remove(s);
                              _dirty = true;
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppStyles.gapL),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _color,
                            decoration: AppStyles.input('Цвет', icon: Icons.palette_outlined),
                          ),
                        ),
                        const SizedBox(width: AppStyles.gapM),
                        Expanded(
                          child: TextFormField(
                            controller: _weight,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: AppStyles.input('Вес, г', icon: Icons.scale_outlined),
                            validator: (v) => (int.tryParse(v ?? '') ?? 0) > 3000 ? 'Не более 3000 г' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppStyles.gapL),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _material,
                            decoration: AppStyles.input('Материал верха', icon: Icons.layers_outlined),
                          ),
                        ),
                        const SizedBox(width: AppStyles.gapM),
                        Expanded(
                          child: TextFormField(
                            controller: _surface,
                            decoration: AppStyles.input('Покрытие', icon: Icons.landscape_outlined),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppStyles.gapL),
                    TextFormField(
                      controller: _description,
                      maxLines: 5,
                      maxLength: 2000,
                      decoration: AppStyles.input('Описание'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('В наличии'),
                      subtitle: const Text('Клиенты смогут бронировать модель'),
                      value: _inStock,
                      onChanged: (v) => setState(() {
                        _inStock = v;
                        _dirty = true;
                      }),
                    ),
                    const SizedBox(height: AppStyles.gapL),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_isNew ? 'Добавить в каталог' : 'Сохранить изменения'),
                    ),
                    const SizedBox(height: AppStyles.gapXL),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagePreview() => SizedBox(
    height: 220,
    child: ShoeImage(
      key: ValueKey(_imageUrl.text),
      url: _imageUrl.text.trim(),
      category: _category,
      borderRadius: AppStyles.cardRadius,
    ),
  );
}
