// import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:slotbooking/Admin/bookings/admin_booking_screen.dart';
import 'package:slotbooking/Admin/bookings/admin_edit_booking_screen.dart';
import 'package:slotbooking/Admin/ground/add_edit_ground_screen.dart';
import 'package:slotbooking/Admin/ground/my_grounds_screen.dart';
import 'package:slotbooking/Admin/revenue/revenue_report_screen.dart';
import 'package:slotbooking/Admin/slots/slot_management_screen.dart';
import 'package:slotbooking/User/booking/bookinghistory.dart';
import 'package:slotbooking/User/home/dashboard.dart';
import 'package:slotbooking/User/home/ground_detail.dart';
import 'package:slotbooking/User/payments/booking_payment_screen.dart';
import 'package:slotbooking/User/slot_selections/slot.dart';
import 'package:slotbooking/features/auth/screens/otp_screen.dart';
import 'package:slotbooking/features/auth/screens/splash_screen.dart';
import 'package:slotbooking/features/auth/screens/roal_selection_screen.dart';
import 'package:slotbooking/features/auth/screens/login_screen.dart';
import 'package:slotbooking/features/auth/screens/register_screen.dart';
import 'package:slotbooking/Admin/admin_shell.dart';
import 'package:slotbooking/Admin/dashboard/admin_dashboard_screen.dart';
import 'package:slotbooking/features/auth/screens/userlogin_screen.dart';

final GoRouter router = GoRouter(
  initialLocation: '/',

  redirect: (context, state) {
    final loggedIn = FirebaseAuth.instance.currentUser != null;

    final publicRoutes = [
      '/',
      '/role-selection',
      '/admin/login',
      '/user/login',
      '/user/otp',
      '/admin/register',
      '/user/register',
      '/master/register',
    ];

    final isPublic = publicRoutes.contains(state.uri.path);

    if (!loggedIn && !isPublic) {
      return '/';
    }

    return null;
  },

  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),

    GoRoute(
      path: '/role-selection',
      builder: (context, state) => const RoleSelectionScreen(),
    ),

    GoRoute(
      path: '/admin/login',
      builder: (context, state) {
        final role = state.uri.queryParameters['role'] ?? 'admin';
        return AdminLoginScreen(role: role);
      },
    ),

    // ── User login (phone OTP) ───────────────────────────────────────────────
    GoRoute(path: '/user/login', builder: (_, __) => const UserLoginScreen()),

    // ── OTP screen — /otp?phone=+91xxxxxxxxxx ────────────────────────────────
    GoRoute(
      path: '/user/otp',
      builder: (_, state) {
        final phone = Uri.decodeComponent(
          state.uri.queryParameters['phone'] ?? '',
        );
        return OtpScreen(phoneNumber: phone);
      },
    ),

    // GoRoute(
    //   path: '/master/login',
    //   builder: (context, state) {
    //     final role = state.uri.queryParameters['role'] ?? 'master';

    //     return AdminLoginScreen(role: role);
    //     // Later replace with:
    //     // return MasterLoginScreen(role: role);
    //   },
    // ),
    GoRoute(
      path: '/admin/register',
      builder: (context, state) {
        final role = state.uri.queryParameters['role'] ?? 'admin';
        return AdminRegisterScreen();
      },
    ),

    GoRoute(
      path: '/admin/dashboard',
      builder: (context, state) {
        return const AdminShell(child: AdminDashboardScreen());
      },
    ),

    GoRoute(
      path: '/admin/slotmanagement',
      builder: (context, state) {
        return const AdminShell(child: AddSlotScreen());
      },
    ),
    GoRoute(
      path: '/admin/slot',
      builder: (context, state) {
        return const AdminShell(child: AdminBookingsScreen());
      },
    ),
    GoRoute(
      path: '/admin/addgrounds',
      builder: (context, state) {
        return const AdminShell(child: AddGroundScreen());
      },
    ),
    GoRoute(
      path: '/admin/grounds',
      builder: (context, state) {
        return const AdminShell(child: AdminGroundsScreen());
      },
    ),

     GoRoute(
      path: '/admin/revenue',
      builder: (context, state) {
        return const AdminShell(child: RevenueReportScreen());
      },
    ),

    //// user  screens
    GoRoute(
      path: '/user/home',
      builder: (context, state) {
        return HomeScreen();
      },
    ),
    GoRoute(
      path: '/user/ground_details',
      builder: (context, state) {
        final groundId = state.uri.queryParameters['groundId'] ?? '';
        return GroundDetailScreen(groundId: groundId);
      },
    ),
    GoRoute(
      path: '/user/slot',
      builder: (context, state) {
        final groundId = state.uri.queryParameters['groundId'] ?? '';
        return SlotBookingScreen(groundId: groundId);
      },
    ),
    GoRoute(
      path: '/user/payment',
      builder: (context, state) {
        final bookingData = state.extra as Map<String, dynamic>? ?? {};
        return BookingPaymentScreen(bookingData: bookingData);
      },
    ),
    GoRoute(
      path: '/user/transaction',
      builder: (context, state) {
        return TransactionHistoryScreen();
      },
    ),
    GoRoute(
      path: '/user/booking_history',
      builder: (context, state) {
        return BookingHistoryScreen();
      },
    ),
  ],
);
