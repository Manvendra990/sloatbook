import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class UserNavBar extends StatelessWidget {
  final int currentIndex;

  const UserNavBar({super.key, required this.currentIndex});

  static const _green = Color(0xFF0D5C3A);
  static const _bg = Color(0xFFF5F7F5);

  static const _items = [
    _NavItem(
      icon: Icons.grid_view_rounded,
      label: 'Home',
      route: '/user/dashboard',
    ),
    _NavItem(
      icon: Icons.access_time_rounded,
      label: 'Slots',
      route: '/user/slots_selection',
    ),
    _NavItem(
      icon: Icons.book_online_rounded,
      label: 'Bookings',
      route: '/user/bookings',
    ),
    _NavItem(
      icon: Icons.attach_money_rounded,
      label: 'Payments',
      route: '/user/payments',
    ),
    _NavItem(
      icon: Icons.person_rounded,
      label: 'Profile',
      route: '/user/profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final isActive = currentIndex == i;
              return GestureDetector(
                onTap: () {
                  if (!isActive) context.go(item.route);
                },
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? _green.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.icon,
                        size: 22,
                        color: isActive ? _green : Colors.grey[400],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: isActive ? _green : Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}
