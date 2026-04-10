import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppStatusPage extends StatefulWidget {
  const AppStatusPage({super.key});

  @override
  State<AppStatusPage> createState() => _AppStatusPageState();
}

class _AppStatusPageState extends State<AppStatusPage> {
  final supabase = Supabase.instance.client;

  bool isOpen = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future load() async {
    final data = await supabase
        .from('app_status')
        .select()
        .eq("id", 1)
        .single();

    setState(() {
      isOpen = data["is_open"];
    });
  }

  Future toggle(bool v) async {
    await supabase
        .from('app_status')
        .update({"is_open": v})
        .eq("id", 1)
        .select(); // 🔥 مهم

    setState(() {
      isOpen = v;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff7f7f7),

      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white,
        title: const Text("حالة المطعم", style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),

      body: Center(
        child: Container(
          padding: const EdgeInsets.all(25),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              /// ICON
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isOpen
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOpen ? Icons.storefront : Icons.store_mall_directory,
                  color: isOpen ? Colors.green : Colors.red,
                  size: 35,
                ),
              ),

              const SizedBox(height: 15),

              /// TITLE
              Text(
                isOpen ? "المطعم مفتوح" : "المطعم مغلق",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isOpen ? Colors.green : Colors.red,
                ),
              ),

              const SizedBox(height: 8),

              /// DESCRIPTION
              Text(
                isOpen
                    ? "التطبيق يستقبل الطلبات حالياً"
                    : "التطبيق متوقف عن استقبال الطلبات",
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              /// SWITCH
              Switch(
                value: isOpen,
                onChanged: (v) {
                  setState(() {
                    isOpen = v; // 🔥 تحديث فوري
                  });

                  toggle(v);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
