import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddOfferPage extends StatefulWidget {
  const AddOfferPage({super.key});

  @override
  State<AddOfferPage> createState() => _AddOfferPageState();
}

class _AddOfferPageState extends State<AddOfferPage> {
  final titleController = TextEditingController();
  final subtitleController = TextEditingController();
  final subtitle2Controller = TextEditingController();

  File? imageFile;

  bool loading = false;

  /// اختيار صورة
  Future pickImage() async {
    final picker = ImagePicker();

    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        imageFile = File(picked.path);
      });
    }
  }

  /// رفع الصورة + إضافة العرض
  Future addOffer() async {
    try {
      if (imageFile == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("اختر صورة")));
        return;
      }

      setState(() {
        loading = true;
      });

      final fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";

      /// رفع الصورة
      await Supabase.instance.client.storage
          .from("offers")
          .upload(
            fileName,
            imageFile!,
            fileOptions: const FileOptions(contentType: "image/jpeg"),
          );

      /// رابط الصورة
      final imageUrl = Supabase.instance.client.storage
          .from("offers")
          .getPublicUrl(fileName);

      /// إضافة العرض في الجدول
      await Supabase.instance.client.from("offers").insert({
        "title": titleController.text,
        "subtitle": subtitleController.text,
        "subtitle2": subtitle2Controller.text,
        "image_url": imageUrl,
        "active": true,
      });

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("تم إضافة العرض")));

      titleController.clear();
      subtitleController.clear();
      subtitle2Controller.clear();

      setState(() {
        imageFile = null;
      });
    } catch (e) {
      setState(() {
        loading = false;
      });

      print("ERROR: $e");

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("إضافة عرض")),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [
            /// الصورة
            GestureDetector(
              onTap: pickImage,

              child: Container(
                height: 180,
                width: double.infinity,

                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(15),
                ),

                child: imageFile == null
                    ? const Center(child: Icon(Icons.add_a_photo, size: 40))
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.file(imageFile!, fit: BoxFit.cover),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            /// العنوان
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: "عنوان العرض",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            /// العنوان الفرعي
            TextField(
              controller: subtitleController,
              decoration: const InputDecoration(
                labelText: "العنوان الفرعي",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            /// عنوان إضافي
            TextField(
              controller: subtitle2Controller,
              decoration: const InputDecoration(
                labelText: "عنوان إضافي",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 30),

            /// زر الإضافة
            SizedBox(
              width: double.infinity,

              child: ElevatedButton(
                onPressed: loading ? null : addOffer,

                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(15),
                ),

                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("إضافة العرض"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
