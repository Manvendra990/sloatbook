import 'package:flutter/material.dart';
import 'package:slotbooking/Admin/admin_shell.dart';

class AdminHeader extends StatelessWidget {
  final String title;
  const AdminHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black12, width: 2)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 1, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 20),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () {
                final shell = AdminShellScope.of(context);
                if (shell != null) {
                  shell.openDrawer();
                } else {
                  Scaffold.of(context).openDrawer();
                }
              },
            ),
          ),

          const Spacer(),

          // Logo
          const Text(
            'KINETIC',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              color: Color(0xFF0D5C3A),
            ),
          ),
          const Spacer(),

          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),

          // Bell
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                color: Colors.grey[700],
                onPressed: () {},
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 30),
        ],
      ),
    );
  }
}
