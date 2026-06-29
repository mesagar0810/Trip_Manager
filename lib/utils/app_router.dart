import 'package:go_router/go_router.dart';
import 'package:trip_manager/screens/auth/login_screen.dart';
import 'package:trip_manager/screens/auth/signup_screen.dart';
import 'package:trip_manager/screens/user/user_home_screen.dart';
import 'package:trip_manager/screens/user/request_trip_screen.dart';
import 'package:trip_manager/screens/user/trip_status_screen.dart';
import 'package:trip_manager/screens/user/trip_detail_user_screen.dart';
import 'package:trip_manager/screens/user/vehicle_select_screen.dart';
import 'package:trip_manager/screens/user/declaration_screen.dart';
import 'package:trip_manager/screens/user/journey_screen.dart';
import 'package:trip_manager/screens/admin/admin_home_screen.dart';
import 'package:trip_manager/screens/admin/admin_trip_review_screen.dart';
import 'package:trip_manager/screens/admin/trip_detail_admin_screen.dart';
import 'package:trip_manager/screens/admin/live_track_screen.dart';
import 'package:trip_manager/screens/admin/manage_drivers_screen.dart';
import 'package:trip_manager/screens/admin/manage_vehicles_screen.dart';
import 'package:trip_manager/services/supabase_service.dart';

class AppRouter {
  static String _userRole = 'user';
  static set userRole(String r) => _userRole = r;
  static String get userRole => _userRole;

  static final router = GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final loggedIn = SupabaseService.currentUser != null;
      if (!loggedIn) {
        _userRole = 'user';
      }
      final onAuth = state.uri.path == '/login' || state.uri.path == '/signup';
      if (!loggedIn && !onAuth) return '/login';
      if (loggedIn && onAuth) return _userRole == 'admin' ? '/admin' : '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (c, s) => const SignupScreen()),
      // User routes
      GoRoute(path: '/home', builder: (c, s) => const UserHomeScreen()),
      GoRoute(path: '/request-trip', builder: (c, s) => const RequestTripScreen()),
      GoRoute(path: '/my-trips', builder: (c, s) => TripStatusScreen(initialTab: s.uri.queryParameters['tab'])),
      GoRoute(path: '/trip-detail-user/:id', builder: (c, s) => TripDetailUserScreen(tripId: s.pathParameters['id']!)),
      GoRoute(path: '/select-vehicle/:tripId', builder: (c, s) => VehicleSelectScreen(tripId: s.pathParameters['tripId']!)),
      GoRoute(path: '/declaration/:assignmentId/:tripId', builder: (c, s) => DeclarationScreen(assignmentId: s.pathParameters['assignmentId']!, tripId: s.pathParameters['tripId']!)),
      GoRoute(path: '/journey/:tripId/:logId', builder: (c, s) => JourneyScreen(tripId: s.pathParameters['tripId']!, logId: s.pathParameters['logId']!)),
      // Admin routes
      GoRoute(path: '/admin', builder: (c, s) => const AdminHomeScreen()),
      GoRoute(path: '/admin/review/:id', builder: (c, s) => AdminTripReviewScreen(tripId: s.pathParameters['id']!)),
      GoRoute(path: '/admin/trip-detail/:id', builder: (c, s) => TripDetailAdminScreen(tripId: s.pathParameters['id']!)),
      GoRoute(path: '/admin/track/:tripId', builder: (c, s) => LiveTrackScreen(tripId: s.pathParameters['tripId']!)),
      GoRoute(path: '/admin/drivers', builder: (c, s) => const ManageDriversScreen()),
      GoRoute(path: '/admin/vehicles', builder: (c, s) => const ManageVehiclesScreen()),
    ],
  );
}
