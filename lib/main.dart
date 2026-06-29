import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:trip_manager/theme/app_theme.dart';
import 'package:trip_manager/utils/app_router.dart';
import 'package:trip_manager/services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  
  await SupabaseService.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // Auto-seed default Admin account
  try {
    await SupabaseService.signUp('Admin', 'Admin@12345', 'admin');
    debugPrint('=== Default Admin account seeded successfully (Admin / Admin@12345) ===');
  } catch (e) {
    debugPrint('=== Default Admin seeding skipped (already exists or error): $e ===');
  }

  // Always boot to the login screen by signing out any active or seeded session on startup
  try {
    await SupabaseService.signOut();
  } catch (_) {}

  runApp(const TripManagerApp());
}

class TripManagerApp extends StatelessWidget {
  const TripManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Trip Manager',
      theme: AppTheme.light,
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}
