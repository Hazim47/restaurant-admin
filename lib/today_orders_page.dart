import 'dart:async'; // ✅ جديد

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class TodayOrdersPage extends StatefulWidget {
  const TodayOrdersPage({super.key});

  @override
  State<TodayOrdersPage> createState() => _TodayOrdersPageState();
}

class _TodayOrdersPageState extends State<TodayOrdersPage> {
  final supabase = Supabase.instance.client;
  List orders = [];
  int rejectedCount = 0;
  int completedCount = 0;
  double todayProfit = 0.0;
  late RealtimeChannel channel;

  Timer? _debounce; // ✅ جديد

  @override
  void initState() {
    super.initState();
    loadTodayOrders();
    subscribeRealtime();
  }

  @override
  void dispose() {
    supabase.removeChannel(channel);
    _debounce?.cancel(); // ✅ مهم
    super.dispose();
  }

  // -------------------- Debounce Reload --------------------
  void safeReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      loadTodayOrders();
    });
  }

  // -------------------- Load Today's Orders --------------------
  Future loadTodayOrders() async {
    // ✅ حل مشكلة التوقيت
    DateTime now = DateTime.now().toUtc();
    DateTime todayStart = DateTime.utc(now.year, now.month, now.day);
    DateTime todayEnd = todayStart.add(const Duration(days: 1));

    final data = await supabase
        .from('orders')
        .select('*, order_items(*)')
        .gte('created_at', todayStart.toIso8601String())
        .lt('created_at', todayEnd.toIso8601String())
        .order('created_at', ascending: false);

    int rejected = 0;
    int completed = 0;
    double profit = 0.0;

    List filteredOrders = [];
    Set seenIds = {};

    for (var order in data) {
      // ✅ بدل الحذف، خليها فاضية
      if (order['order_items'] == null) {
        order['order_items'] = [];
      }

      if (seenIds.contains(order['id'])) continue;
      seenIds.add(order['id']);
      filteredOrders.add(order);

      if (order['status'] == 'rejected') rejected++;

      if (order['status'] == 'done') {
        completed++;
        double itemsTotal = 0.0;

        for (var item in order['order_items']) {
          itemsTotal +=
              ((item['price'] ?? 0).toDouble() * (item['quantity'] ?? 1));
        }

        profit += itemsTotal + (order['delivery_price'] ?? 0).toDouble();
      }
    }

    setState(() {
      orders = filteredOrders;
      rejectedCount = rejected;
      completedCount = completed;
      todayProfit = profit;
    });
  }

  // -------------------- Realtime --------------------
  void subscribeRealtime() {
    channel = supabase.channel('orders_channel');

    // orders
    channel.on(
      RealtimeListenTypes.postgresChanges,
      ChannelFilter(event: '*', schema: 'public', table: 'orders'),
      (payload, [ref]) => safeReload(), // ✅ بدل load مباشرة
    );

    // ✅ مهم جداً: order_items
    channel.on(
      RealtimeListenTypes.postgresChanges,
      ChannelFilter(event: '*', schema: 'public', table: 'order_items'),
      (payload, [ref]) => safeReload(),
    );

    channel.subscribe();
  }

  // -------------------- Build Order Card --------------------
  Widget buildOrderCard(order) {
    final items = order['order_items'] ?? [];
    double itemsTotal = 0;

    for (var item in items) {
      itemsTotal +=
          ((item['price'] ?? 0).toDouble() *
          (item['quantity'] ?? 1).toDouble());
    }

    double deliveryPrice = (order['delivery_price'] ?? 0).toDouble();
    double total = itemsTotal + deliveryPrice;

    Color statusColor;
    String statusText;

    switch (order['status']) {
      case 'accepted':
        statusText = 'مقبول';
        statusColor = Colors.orange;
        break;
      case 'rejected':
        statusText = 'مرفوض';
        statusColor = Colors.red;
        break;
      case 'done':
        statusText = 'تم التسليم';
        statusColor = Colors.green;
        break;
      default:
        statusText = 'قيد الانتظار';
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "طلب #${order["daily_number"]}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  DateFormat('HH:mm').format(
                    DateTime.parse(order['created_at']).toLocal(),
                  ), // ✅ عرض صحيح
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text("👤 ${order['customer_name']}"),
            Text("📞 ${order['phone']}"),
            const SizedBox(height: 6),
            Text(
              "المجموع: ${total.toStringAsFixed(2)} JD",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text("الحالة: $statusText", style: TextStyle(color: statusColor)),
          ],
        ),
      ),
    );
  }

  // -------------------- Build --------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("طلبات اليوم"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      "$completedCount",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const Text("تم التسليم"),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      "$rejectedCount",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const Text("مرفوض"),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      "${todayProfit.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const Text("الربح JD"),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: orders.isEmpty
                ? const Center(child: Text("لا يوجد طلبات اليوم"))
                : ListView.builder(
                    itemCount: orders.length,
                    itemBuilder: (context, index) =>
                        buildOrderCard(orders[index]),
                  ),
          ),
        ],
      ),
    );
  }
}
