import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  final supabase = Supabase.instance.client;

  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _mealPriceController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _category;
  File? _image;
  bool _loading = false;
  int? _editingId;

  List<dynamic> _menuItems = [];

  final _categories = [
    "وجبات شاورما",
    "سناكات",
    "وجبات عائلية",
    "وجبات بروستد",
    "مقبلات",
    "مشروبات",
  ];

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  Future<void> _loadMenu() async {
    final res = await supabase
        .from('menu')
        .select('id,name,price,meal_price,description,category,image_url')
        .order('id');

    setState(() => _menuItems = res);
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _image = File(picked.path));
    }
  }

  Future<String?> uploadImage(File file) async {
    final fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";
    await supabase.storage.from('menu-images').upload(fileName, file);
    return supabase.storage.from('menu-images').getPublicUrl(fileName);
  }

  Future<void> _saveMenuItem() async {
    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    final mealPrice = double.tryParse(_mealPriceController.text.trim());
    final description = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();

    if (name.isEmpty || _category == null || price == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("اسم المنتج والسعر والفئة مطلوبين")),
      );
      return;
    }

    setState(() => _loading = true);

    String? imageUrl;
    if (_image != null) {
      imageUrl = await uploadImage(_image!);
    }

    if (_editingId != null) {
      await supabase
          .from('menu')
          .update({
            'name': name,
            'price': price,
            'meal_price': mealPrice,
            if (description != null) 'description': description,
            'category': _category,
            if (imageUrl != null) 'image_url': imageUrl,
          })
          .eq('id', _editingId);
    } else {
      await supabase.from('menu').insert({
        'name': name,
        'price': price,
        'meal_price': mealPrice,
        if (description != null) 'description': description,
        'category': _category,
        'image_url': imageUrl ?? "",
      });
    }

    _resetForm();
    await _loadMenu();
    setState(() => _loading = false);
  }

  void _resetForm() {
    _nameController.clear();
    _priceController.clear();
    _mealPriceController.clear();
    _descriptionController.clear();
    _category = null;
    _image = null;
    _editingId = null;
    setState(() {});
  }

  void _editItem(dynamic item) {
    _editingId = item['id'];
    _nameController.text = item['name'];
    _priceController.text = item['price'].toString();
    _mealPriceController.text = item['meal_price']?.toString() ?? "";
    _descriptionController.text = item['description'] ?? "";
    _category = item['category'];
    setState(() {});
  }

  Future<void> _deleteMenuItem(int id) async {
    await supabase.from('menu').delete().eq('id', id);
    await _loadMenu();
  }

  bool showMealPrice() => _category == "سناكات";

  bool showDescription() =>
      _category == "مقبلات" ||
      _category == "وجبات بروستد" ||
      _category == "وجبات شاورما" ||
      _category == "وجبات عائلية";

  @override
  Widget build(BuildContext context) {
    Map<String, List<dynamic>> categorized = {};

    for (var cat in _categories) {
      categorized[cat] = _menuItems
          .where((item) => item['category'] == cat)
          .toList();
    }

    return Scaffold(
      backgroundColor: const Color(0xfff7f7f7),

      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white,
        title: const Text(
          "Menu Management",
          style: TextStyle(color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// FORM
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: _input("اسم المنتج *"),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: _input("السعر"),
                  ),

                  if (showMealPrice())
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: TextField(
                        controller: _mealPriceController,
                        keyboardType: TextInputType.number,
                        decoration: _input("سعر الوجبة"),
                      ),
                    ),

                  if (showDescription())
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: TextField(
                        controller: _descriptionController,
                        maxLines: 2,
                        decoration: _input("وصف المنتج"),
                      ),
                    ),

                  const SizedBox(height: 10),

                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration: _input("اختيار الفئة"),
                    items: _categories
                        .map(
                          (cat) =>
                              DropdownMenuItem(value: cat, child: Text(cat)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _category = v),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.image),
                        label: const Text("صورة"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orangeAccent,
                          foregroundColor: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (_image != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(_image!, width: 60, height: 60),
                        ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _saveMenuItem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(_editingId != null ? "تحديث" : "إضافة"),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            /// LIST
            ..._categories.map((cat) {
              final items = categorized[cat]!;

              if (items.isEmpty) return const SizedBox();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cat,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange,
                    ),
                  ),
                  const SizedBox(height: 10),

                  ...items.map((item) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          if (item['image_url'] != null &&
                              item['image_url'] != "")
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: item['image_url'],
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                              ),
                            ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),

                                /// 🔥 الوصف (إذا موجود)
                                if (item['description'] != null &&
                                    item['description'].toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      item['description'],
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),

                                const SizedBox(height: 4),

                                Text(
                                  "${item['price']} JD",
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),

                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.orange),
                            onPressed: () => _editItem(item),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteMenuItem(item['id']),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 20),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  InputDecoration _input(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey.shade100,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }
}
