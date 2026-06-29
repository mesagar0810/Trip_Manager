import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trip_manager/services/supabase_service.dart';
import 'package:trip_manager/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});
  @override State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  String _username = '';
  int _pendingCount = 0;
  int _approvedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    final profile = await SupabaseService.getUserProfile(uid);
    final trips = await SupabaseService.getTripsForUser(uid);
    if (mounted) setState(() {
      _username = profile?['user_name'] ?? '';
      _pendingCount = trips.where((t) => t['status'] == 'pending').length;
      _approvedCount = trips.where((t) => t['status'] == 'approved').length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Hello,', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
                Text(_username, style: Theme.of(context).textTheme.titleLarge),
              ]),
              IconButton(
                onPressed: () async { await SupabaseService.signOut(); if (mounted) context.go('/login'); },
                icon: const Icon(Icons.logout_rounded),
                style: IconButton.styleFrom(backgroundColor: AppColors.surfaceAlt),
              ),
            ]),
            const SizedBox(height: 28),
            Row(children: [
              _statCard('Pending', _pendingCount, AppColors.pendingBg, AppColors.pending, () => context.go('/my-trips?tab=Pending')),
              const SizedBox(width: 12),
              _statCard('Approved', _approvedCount, AppColors.approvedBg, AppColors.approved, () => context.go('/my-trips?tab=Approved')),
            ]).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
            const SizedBox(height: 28),
            Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            _actionCard(
              icon: Icons.add_road_rounded,
              title: 'Request New Trip',
              subtitle: 'Submit a new travel request',
              color: AppColors.primary,
              onTap: () => context.go('/request-trip'),
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 12),
            _actionCard(
              icon: Icons.receipt_long_rounded,
              title: 'My Trips',
              subtitle: 'View status of all your requests',
              color: AppColors.primaryLight,
              onTap: () => context.go('/my-trips'),
            ).animate().fadeIn(delay: 400.ms),
          ]),
        ),
      ),
    );
  }

  Widget _statCard(String label, int count, Color bg, Color fg, VoidCallback onTap) => Expanded(
    child: Card(
      color: bg,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$count', style: GoogleFonts.sora(fontSize: 28, fontWeight: FontWeight.w700, color: fg)),
            Text(label, style: GoogleFonts.inter(fontSize: 13, color: fg.withOpacity(0.8))),
          ]),
        ),
      ),
    ),
  );

  Widget _actionCard({required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ])),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
          ]),
        ),
      ),
    );
  }

}
