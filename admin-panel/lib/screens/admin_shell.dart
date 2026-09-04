import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/admin_api.dart';
import 'dashboard_screen.dart';
import 'users_screen.dart';
import 'vendors_screen.dart';
import 'bookings_screen.dart';
import 'categories_screen.dart';
import 'settings_screen.dart';

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _page = 0;

  static const _pages = [
    DashboardScreen(),
    UsersScreen(),
    VendorsScreen(),
    BookingsScreen(),
    CategoriesScreen(),
    SettingsScreen(),
  ];

  static const _navItems = [
    (icon: Icons.dashboard_rounded, label: 'الرئيسية'),
    (icon: Icons.people_rounded, label: 'المستخدمين'),
    (icon: Icons.store_rounded, label: 'البائعين'),
    (icon: Icons.calendar_month_rounded, label: 'الحجوزات'),
    (icon: Icons.category_rounded, label: 'التصنيفات'),
    (icon: Icons.settings_rounded, label: 'الإعدادات'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(children: [
        // شريط جانبي
        Container(
          width: 240,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(left: BorderSide(color: Colors.grey[200]!)),
          ),
          child: Column(children: [
            // شعار
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: const Color(0xFF0AAEBF).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF0AAEBF), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('لوحة التحكم', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                    Text('شهاب ماركت بليس', style: TextStyle(fontSize: 11, color: Color(0xFF8AA9AD))),
                  ],
                )),
              ]),
            ),
            Divider(height: 1, color: Colors.grey[200]),
            const SizedBox(height: 8),
            // عناصر التنقل
            for (var i = 0; i < _navItems.length; i++)
              _NavButton(
                icon: _navItems[i].icon,
                label: _navItems[i].label,
                selected: _page == i,
                onTap: () => setState(() => _page = i),
              ),
            const Spacer(),
            Divider(height: 1, color: Colors.grey[200]),
            // تسجيل خروج
            _NavButton(
              icon: Icons.logout_rounded,
              label: 'تسجيل الخروج',
              selected: false,
              isLogout: true,
              onTap: () => ref.read(adminApiProvider).logout(),
            ),
            const SizedBox(height: 12),
          ]),
        ),
        // المحتوى
        Expanded(child: _pages[_page]),
      ]),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.label, required this.selected, required this.onTap, this.isLogout = false});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isLogout;

  @override
  Widget build(BuildContext context) {
    final color = isLogout ? const Color(0xFFE5392B) : selected ? const Color(0xFF0AAEBF) : const Color(0xFF6B6B6B);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? const Color(0xFF0AAEBF).withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 12),
              Text(label, style: TextStyle(fontSize: 14, fontWeight: selected ? FontWeight.w600 : FontWeight.w500, color: color)),
            ]),
          ),
        ),
      ),
    );
  }
}
