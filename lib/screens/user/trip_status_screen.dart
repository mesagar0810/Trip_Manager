import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trip_manager/models/trip_model.dart';
import 'package:trip_manager/services/supabase_service.dart';
import 'package:trip_manager/theme/app_theme.dart';
import 'package:trip_manager/widgets/trip_card.dart';

class TripStatusScreen extends StatefulWidget {
  final String? initialTab;
  const TripStatusScreen({super.key, this.initialTab});
  @override State<TripStatusScreen> createState() => _TripStatusScreenState();
}

class _TripStatusScreenState extends State<TripStatusScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<TripModel> _trips = [];
  bool _loading = true;
  String? _error;
  final _tabs = ['All', 'Pending', 'Approved', 'Rejected'];

  @override
  void initState() {
    super.initState();
    int initialIndex = 0;
    if (widget.initialTab != null) {
      final idx = _tabs.indexWhere((t) => t.toLowerCase() == widget.initialTab!.toLowerCase());
      if (idx != -1) initialIndex = idx;
    }
    _tabController = TabController(length: _tabs.length, vsync: this, initialIndex: initialIndex);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = SupabaseService.currentUser?.id;
      if (uid == null) {
        setState(() {
          _error = 'User session not found';
          _loading = false;
        });
        return;
      }
      final data = await SupabaseService.getTripsForUser(uid);
      setState(() {
        _trips = data.map((e) => TripModel.fromJson(e)).toList();
        _loading = false;
      });
    } catch (e, stack) {
      debugPrint('Error loading user trips: $e\n$stack');
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<TripModel> _filtered(String tab) {
    if (tab == 'All') return _trips;
    return _trips.where((t) => t.status.label == tab).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/home')),
        title: const Text('My Trips'),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
          unselectedLabelColor: AppColors.textSecondary,
          labelColor: AppColors.primary,
          indicatorColor: AppColors.primary,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 56, color: AppColors.rejected),
                        const SizedBox(height: 12),
                        Text('Failed to load trips', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _load,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(160, 44),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
              controller: _tabController,
              children: _tabs.map((tab) {
                final trips = _filtered(tab);
                if (trips.isEmpty) return _empty(tab);
                return RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: trips.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final trip = trips[i];
                      Widget? trailing;
                      if (trip.status == TripStatus.approved && trip.assignment == null) {
                        trailing = ElevatedButton.icon(
                          icon: const Icon(Icons.directions_car, size: 16),
                          label: const Text('Select Vehicle'),
                          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 16)),
                          onPressed: () => context.go('/select-vehicle/${trip.id}'),
                        );
                      } else if (trip.status == TripStatus.approved && trip.assignment != null && trip.assignment!.declaration == null) {
                        trailing = ElevatedButton.icon(
                          icon: const Icon(Icons.assignment, size: 16),
                          label: const Text('Fill Declaration'),
                          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 16), backgroundColor: AppColors.pending),
                          onPressed: () => context.go('/declaration/${trip.assignment!.id}/${trip.id}'),
                        );
                      } else if (trip.status == TripStatus.approved && trip.assignment?.declaration?.submitted == true) {
                        trailing = ElevatedButton.icon(
                          icon: const Icon(Icons.play_arrow_rounded, size: 16),
                          label: const Text('Start Journey'),
                          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 16), backgroundColor: AppColors.approved),
                          onPressed: () => context.go('/journey/${trip.id}/new'),
                        );
                      } else if (trip.status == TripStatus.rejected) {
                        trailing = OutlinedButton.icon(
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Request Again'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 16)),
                          onPressed: () => context.go('/request-trip'),
                        );
                      }
                      return TripCard(trip: trip, onTap: () => context.go('/trip-detail-user/${trip.id}'), trailing: trailing);
                    },
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _empty(String tab) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.inbox_outlined, size: 56, color: AppColors.textHint),
    const SizedBox(height: 12),
    Text('No ${tab == 'All' ? '' : tab.toLowerCase()} trips yet', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary)),
    if (tab == 'All' || tab == 'Pending') ...[
      const SizedBox(height: 16),
      ElevatedButton(onPressed: () => context.go('/request-trip'), child: const Text('Request a Trip'), style: ElevatedButton.styleFrom(minimumSize: const Size(160, 44))),
    ]
  ]));
}
