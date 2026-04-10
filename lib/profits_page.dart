import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfitsPage extends StatefulWidget {
  const ProfitsPage({super.key});

  @override
  State<ProfitsPage> createState() => _ProfitsPageState();
}

class _ProfitsPageState extends State<ProfitsPage> {
  final supabase = Supabase.instance.client;

  List profits = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future load() async {
    final data = await supabase.from('orders').select().eq("status", "done");

    Map<String, double> monthly = {};

    for (var o in data) {
      final date = DateTime.parse(o["created_at"]);
      final key = "${date.year}-${date.month}";

      final price = double.tryParse(o["total_price"].toString()) ?? 0;

      monthly[key] = (monthly[key] ?? 0) + price;
    }

    final result = monthly.entries
        .map((e) => {"month": e.key, "total": e.value})
        .toList();

    setState(() {
      profits = result;
    });
  }

  String formatMonth(String key) {
    final parts = key.split("-");
    return "شهر ${parts[1]} / ${parts[0]}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f5f5),

      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.white,
        title: const Text(
          "الأرباح الشهرية",
          style: TextStyle(color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),

      body: profits.isEmpty
          ? const Center(
              child: Text(
                "لا يوجد بيانات",
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: profits.length,
              itemBuilder: (context, index) {
                final p = profits[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white, Colors.grey.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
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
                      /// ICON
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.attach_money,
                          color: Colors.green,
                        ),
                      ),

                      const SizedBox(width: 12),

                      /// MONTH
                      Expanded(
                        child: Text(
                          formatMonth(p["month"]),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      /// TOTAL
                      Text(
                        "${p["total"].toStringAsFixed(2)} JD",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
