import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'add_offer_page.dart';

class OffersManagementPage extends StatefulWidget {
  const OffersManagementPage({super.key});

  @override
  State<OffersManagementPage> createState() => _OffersManagementPageState();
}

class _OffersManagementPageState extends State<OffersManagementPage> {
  final supabase = Supabase.instance.client;

  List offers = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadCachedOffers(); // 🔥 أول شي نجيب من الكاش
    loadOffers(); // 🔥 بعدين نحدث بالخلفية
  }

  /// 🔥 تحميل من الكاش
  Future loadCachedOffers() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString("offers_cache");

    if (cachedData != null) {
      final decoded = jsonDecode(cachedData);

      setState(() {
        offers = decoded;
        loading = false;
      });
    }
  }

  /// 🔥 تحميل من السيرفر + تحديث الكاش
  Future loadOffers() async {
    final data = await supabase
        .from("offers")
        .select()
        .order("created_at", ascending: false);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("offers_cache", jsonEncode(data));

    setState(() {
      offers = data;
      loading = false;
    });
  }

  Future deleteOffer(int id) async {
    await supabase.from("offers").delete().eq("id", id);
    loadOffers();
  }

  Future toggleOffer(int id, bool value) async {
    await supabase.from("offers").update({"active": value}).eq("id", id);
    loadOffers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff6f6f6),

      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white,
        title: const Text(
          "إدارة العروض",
          style: TextStyle(color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepOrange,
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddOfferPage()),
          );
          loadOffers();
        },
      ),

      body: loading && offers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : offers.isEmpty
          ? const Center(
              child: Text("لا يوجد عروض", style: TextStyle(color: Colors.grey)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: offers.length,
              itemBuilder: (context, index) {
                final offer = offers[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      /// 🔥 صورة مع caching قوي
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: offer["image_url"] ?? "",
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          memCacheWidth: 200,
                          memCacheHeight: 200,
                          fadeInDuration: Duration.zero, // 🔥 بدون تحميل وهمي
                          placeholder: (context, url) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey.shade200,
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      /// النصوص
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              offer["title"] ?? "",
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              offer["subtitle"] ?? "",
                              style: const TextStyle(color: Colors.black87),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              offer["subtitle2"] ?? "",
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),

                      /// التحكم
                      Column(
                        children: [
                          Switch(
                            value: offer["active"] ?? true,
                            onChanged: (value) {
                              setState(() {
                                offer["active"] = value;
                              });

                              toggleOffer(offer["id"], value);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              deleteOffer(offer["id"]);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
