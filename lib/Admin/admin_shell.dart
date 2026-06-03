import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdminShell extends StatelessWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(drawer: const _AdminDrawer(), body: child);
  }
}

class _AdminDrawer extends StatelessWidget {
  const _AdminDrawer();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: theme.colorScheme.primary),
            accountName: Text(
              user?.displayName ?? 'Admin',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            accountEmail: Text(user?.email ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundColor: theme.colorScheme.onPrimary,
              child: Text(
                (user?.displayName ?? 'A')[0].toUpperCase(),
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _DrawerItem(
                  icon: Icons.dashboard_outlined,
                  label: 'Dashboard',
                  route: '/admin/dashboard',
                ),
                _DrawerItem(
                  icon: Icons.sports_soccer_outlined,
                  label: 'My grounds',
                  route: '/admin/grounds',
                ),
                _DrawerItem(
                  icon: Icons.schedule_outlined,
                  label: 'Slots & pricing',
                  route: '/admin/slots',
                ),
                _DrawerItem(
                  icon: Icons.book_online_outlined,
                  label: 'Bookings',
                  route: '/admin/bookings',
                ),
                _DrawerItem(
                  icon: Icons.bar_chart_outlined,
                  label: 'Revenue report',
                  route: '/admin/revenue',
                ),
                const Divider(),
                _DrawerItem(
                  icon: Icons.person_outline,
                  label: 'Profile',
                  route: '/admin/profile',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Sign out',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) context.go('/login');
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final current = GoRouterState.of(context).uri.toString();
    final selected = current.startsWith(route);
    final color = selected ? Theme.of(context).colorScheme.primary : null;

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: selected,
      selectedTileColor: Theme.of(
        context,
      ).colorScheme.primary.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: () {
        Navigator.pop(context);
        context.go(route);
      },
    );
  }
}
