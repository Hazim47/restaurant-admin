import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'core/services/supabase_service.dart';
import 'dart:async';
import 'package:intl/intl.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final supabase = Supabase.instance.client;
  final player = AudioPlayer();
  List orders = [];
  bool isPlaying = false;
  Timer? _refreshTimer;
  @override
  void initState() {
    super.initState();
    loadOrders();
    subscribeOrdersRealtime();
    // إعادة تحميل الأوردرات كل 30 ثانية تلقائيًا
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      loadOrders();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel(); // لإيقاف التايمر عند الخروج من الصفحة
    super.dispose();
  }

  // -------------------- Realtime --------------------
  void subscribeOrdersRealtime() {
    final channel = supabase.channel('orders_channel');
    channel.on(
      RealtimeListenTypes.postgresChanges,
      ChannelFilter(event: 'INSERT', schema: 'public', table: 'orders'),
      (payload, [ref]) async {
        final newOrder = payload['new'];
        if (newOrder['status'] == 'pending') {
          await playNotificationSound();
        }
        setState(() {
          orders.insert(0, newOrder); // نضيف الجديد أول القائمة
        });
      },
    );

    channel.on(
      RealtimeListenTypes.postgresChanges,
      ChannelFilter(event: 'UPDATE', schema: 'public', table: 'orders'),
      (payload, [ref]) async {
        final updatedOrder = payload['new'];
        setState(() {
          int index = orders.indexWhere((o) => o['id'] == updatedOrder['id']);
          if (index != -1) {
            orders[index] = updatedOrder;
          }
        });

        if (updatedOrder['status'] == 'accepted' ||
            updatedOrder['status'] == 'rejected') {
          await stopNotificationSound();
        }
      },
    );

    channel.subscribe();
  }

  // -------------------- Notification Sound --------------------
  Future playNotificationSound() async {
    if (isPlaying) return;
    isPlaying = true;
    await player.stop();
    await player.setReleaseMode(ReleaseMode.loop);
    await player.play(AssetSource('beep.mp3'));
  }

  Future stopNotificationSound() async {
    isPlaying = false;
    await player.stop();
  }

  // -------------------- Load Orders --------------------
  Future loadOrders() async {
    final data = await supabase
        .from('orders')
        .select('*, order_items(*)')
        .in_('status', ['pending', 'accepted'])
        .order('created_at', ascending: false);

    setState(() {
      orders = data;
    });

    bool hasPending = data.any((o) => o['status'] == 'pending');
    if (hasPending) {
      playNotificationSound();
    } else {
      stopNotificationSound();
    }
  }

  // -------------------- Accept / Reject / Complete --------------------
  Future acceptOrder(int id, int prepTime, String userId) async {
    await stopNotificationSound();
    await supabase
        .from('orders')
        .update({
          "status": "accepted",
          "preparation_time": prepTime,
          "accepted_at": DateTime.now().toIso8601String(),
        })
        .eq("id", id);

    // إشعار المستخدم
    await SupabaseService.sendNotification(
      userId: userId,
      title: "تم قبول طلبك",
      body: "طلبك سيجهز خلال $prepTime دقيقة.",
    );

    loadOrders();
  }

  Future rejectOrder(int id, String userId) async {
    await stopNotificationSound();
    await supabase.from('orders').update({"status": "rejected"}).eq("id", id);

    // إشعار المستخدم
    await SupabaseService.sendNotification(
      userId: userId,
      title: "تم رفض طلبك",
      body: "نعتذر، تم رفض طلبك.",
    );

    loadOrders();
  }

  Future completeOrder(int id, String userId) async {
    await supabase
        .from('orders')
        .update({
          "status": "done",
          "completed_at": DateTime.now().toIso8601String(),
        })
        .eq("id", id);

    // إشعار المستخدم
    await SupabaseService.sendNotification(
      userId: userId,
      title: "تم تسليم طلبك",
      body: "شكراً لتعاملك معنا، تم تسليم طلبك بنجاح.",
    );

    loadOrders();
  }

  // -------------------- اختيار وقت التحضير --------------------
  void choosePrepTime(order) {
    int? selectedTime;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  /// 🔥 العنوان
                  const Text(
                    "اختيار وقت التحضير",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 15),

                  /// 🔥 الخيارات
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [10, 15, 20, 30].map((time) {
                      final isSelected = selectedTime == time;

                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            selectedTime = time;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 18,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.deepPurple
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.deepPurple
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer,
                                size: 18,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black54,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "$time دقيقة",
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  /// 🔥 زر التأكيد
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedTime == null
                          ? null
                          : () {
                              Navigator.pop(context);
                              acceptOrder(
                                order["id"],
                                selectedTime!,
                                order["user_id"].toString(),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "تأكيد",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget prepButton(order, int minutes) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          acceptOrder(order["id"], minutes, order["user_id"].toString());
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(
          "$minutes دقيقة",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
    );
  }

  // -------------------- Build Order Card --------------------
  Widget buildOrderCard(order) {
    final items = order['order_items'] as List<dynamic>? ?? [];
    double itemsTotal = 0;
    for (var item in items) {
      itemsTotal +=
          ((item['price'] ?? 0).toDouble()) *
          ((item['quantity'] ?? 1).toDouble());
    }

    double deliveryPrice = (order['delivery_price'] ?? 0).toDouble();
    double total = itemsTotal + deliveryPrice;
    bool isNew = order['status'] == 'pending';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isNew ? Colors.orange.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isNew ? Colors.orange : Colors.grey.shade200,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "طلب #${order["daily_number"]}",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isNew ? Colors.deepOrange : Colors.black,
                ),
              ),
              Text(
                DateFormat('hh:mm a').format(
                  DateTime.parse(
                    order["created_at"],
                  ).toLocal(), // تحويل للوقت المحلي
                ),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text("👤 ${order["customer_name"]}"),
          Text("📞 ${order["phone"]}"),
          if (order["delivery_type"] == "delivery") ...[
            Builder(
              builder: (_) {
                String locationText = order["location"] ?? '';
                String detailed = order["detailed_address"] ?? '';
                String finalLocation = detailed.isNotEmpty
                    ? "$locationText / $detailed"
                    : locationText;
                return Text("📍 $finalLocation");
              },
            ),
          ] else ...[
            const Text("📦 استلام من المطعم"),
          ],
          const SizedBox(height: 12),
          const Text(
            "المنتجات:",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          ...items.map((item) {
            final type = item['type'] ?? '';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      type.isNotEmpty
                          ? "${item['product_name']} ($type)"
                          : item['product_name'],
                    ),
                  ),
                  Text("${item['quantity']} × ${item['price']}"),
                ],
              ),
            );
          }),
          const Divider(height: 18),
          Text("الوجبات: ${itemsTotal.toStringAsFixed(2)} JD"),
          Text(
            "التوصيل: ${deliveryPrice.toStringAsFixed(2)} JD",
            style: const TextStyle(color: Colors.green),
          ),
          Text(
            "المجموع: ${total.toStringAsFixed(2)} JD",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      order['status'] ==
                          'pending' // تفعل فقط إذا الطلب ما زال pending
                      ? () => choosePrepTime(order)
                      : null, // إذا تم قبوله، يصبح معطل
                  style: ElevatedButton.styleFrom(
                    backgroundColor: order['status'] == 'pending'
                        ? Colors.green
                        : Colors.grey, // لون رمادي إذا تم الضغط
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text("قبول"),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton(
                  onPressed: () =>
                      rejectOrder(order["id"], order["user_id"].toString()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text("رفض"),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ElevatedButton(
                  onPressed: () =>
                      completeOrder(order["id"], order["user_id"].toString()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text("تسليم"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff7f7f7),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text("الطلبات", style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: orders.isEmpty
          ? const Center(
              child: Text(
                "لا يوجد طلبات",
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: orders.length,
              itemBuilder: (context, index) => buildOrderCard(orders[index]),
            ),
    );
  }
}
