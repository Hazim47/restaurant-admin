import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shawarma_admin/orders_page.dart' as orders;
import 'package:shawarma_admin/menu_page.dart' as menu;
import 'today_orders_page.dart';
import 'profits_page.dart';
import 'add_offer_page.dart';
import 'offers_management_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final supabase = Supabase.instance.client;

  final ValueNotifier<int> newOrdersNotifier = ValueNotifier<int>(0);
  bool isOpen = true;

  @override
  void initState() {
    super.initState();
    loadOrdersCount();
    loadRestaurantStatus();
    subscribeRealtime();
  }

  void subscribeRealtime() {
    final channel = supabase.channel('orders_dashboard');

    channel.on(
      RealtimeListenTypes.postgresChanges,
      ChannelFilter(event: 'INSERT', schema: 'public', table: 'orders'),
      (payload, [ref]) => loadOrdersCount(),
    );

    channel.subscribe();
  }

  Future loadOrdersCount() async {
    final data = await supabase
        .from('orders')
        .select('id')
        .eq("status", "pending");
    newOrdersNotifier.value = data.length;
  }

  Future loadRestaurantStatus() async {
    final data = await supabase
        .from('app_status')
        .select()
        .eq("id", 1)
        .single();
    setState(() => isOpen = data["is_open"]);
  }

  Future toggleRestaurant(bool value) async {
    await supabase.from('app_status').update({"is_open": value}).eq("id", 1);
    setState(() => isOpen = value);
  }

  final List<_DashboardItem> items = [
    _DashboardItem(
      "الطلبات",
      Icons.shopping_bag,
      Colors.deepOrangeAccent,
      orders.OrdersPage(),
    ),
    _DashboardItem(
      "القائمة",
      Icons.restaurant_menu,
      Colors.lightBlueAccent,
      menu.MenuPage(),
    ),
    _DashboardItem(
      "إضافة عرض",
      Icons.local_offer,
      Colors.purpleAccent,
      AddOfferPage(),
    ),
    _DashboardItem(
      "إدارة العروض",
      Icons.campaign,
      Colors.tealAccent,
      OffersManagementPage(),
    ),
    _DashboardItem(
      "طلبات اليوم",
      Icons.history,
      Colors.greenAccent,
      TodayOrdersPage(),
    ),
    _DashboardItem("الأرباح", Icons.bar_chart, Colors.redAccent, ProfitsPage()),
  ];

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff1e1e2f),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xff1e1e2f),
        title: const Text(
          "لوحة التحكم",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            letterSpacing: 0.8,
            color: Colors.white,
          ),
        ),
        actions: [
          Row(
            children: [
              Text(
                isOpen ? "مفتوح" : "مغلق",
                style: TextStyle(
                  color: isOpen
                      ? Colors.greenAccent.shade400
                      : Colors.redAccent.shade400,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: isOpen,
                onChanged: toggleRestaurant,
                activeColor: Colors.greenAccent.shade400,
                inactiveThumbColor: Colors.redAccent.shade400,
              ),
              const SizedBox(width: 12),
            ],
          ),
        ],
      ),
      // هنا أضفنا RefreshIndicator حول الـ GridView
      body: RefreshIndicator(
        color: Colors.greenAccent,
        onRefresh: () async {
          // إعادة تحميل عدد الطلبات وحالة المطعم عند السحب
          await loadOrdersCount();
          await loadRestaurantStatus();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (_, index) {
              final item = items[index];
              return RepaintBoundary(
                child: ValueListenableBuilder<int>(
                  valueListenable: newOrdersNotifier,
                  builder: (_, newOrders, __) {
                    final badge = item.title == "الطلبات" ? newOrders : 0;
                    return _dashboardCard(
                      item.title,
                      item.icon,
                      item.color,
                      item.page,
                      badge,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _dashboardCard(
    String title,
    IconData icon,
    Color color,
    Widget page,
    int badge,
  ) {
    return GestureDetector(
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.85), color.withOpacity(0.35)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: color.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // أيقونة glow بسيطة
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Colors.white24, Colors.transparent],
                        radius: 0.8,
                        center: Alignment.center,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(icon, size: 50, color: Colors.white),
                  ),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black45,
                          offset: Offset(1, 1),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (badge > 0)
              Positioned(
                right: 14,
                top: 14,
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.redAccent.shade400,
                        Colors.redAccent.shade200,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withOpacity(0.7),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Text(
                    badge.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DashboardItem {
  final String title;
  final IconData icon;
  final Color color;
  final Widget page;

  _DashboardItem(this.title, this.icon, this.color, this.page);
}
