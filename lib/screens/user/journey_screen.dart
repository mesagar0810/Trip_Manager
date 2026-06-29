import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trip_manager/services/location_service.dart';
import 'package:trip_manager/services/supabase_service.dart';
import 'package:trip_manager/theme/app_theme.dart';

class JourneyScreen extends StatefulWidget {
  final String tripId;
  final String logId;
  const JourneyScreen({super.key, required this.tripId, required this.logId});
  @override State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  bool _started = false;
  bool _loading = false;
  String? _currentLogId;

  @override
  void initState() {
    super.initState();
    if (widget.logId != 'new') {
      _currentLogId = widget.logId;
      _started = true;
    }
  }

  @override
  void dispose() {
    LocationService.stopTracking();
    super.dispose();
  }

  Future<void> _startJourney() async {
    setState(() => _loading = true);
    try {
      final log = await SupabaseService.startJourney(widget.tripId);
      _currentLogId = log['id'];
      if (_currentLogId != null) {
        final trackingStarted = await LocationService.startTracking(_currentLogId!);
        if (!trackingStarted && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Warning: Location permissions denied. Live tracking is inactive.'),
              backgroundColor: AppColors.rejected,
            ),
          );
        }
      }
      setState(() { _started = true; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _endJourney() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('End Journey?'),
        content: const Text('Are you sure you want to mark this trip as completed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('End Trip')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _loading = true);
    try {
      LocationService.stopTracking();
      await SupabaseService.endJourney(widget.tripId, _currentLogId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trip completed!'), backgroundColor: AppColors.approved));
        context.go('/home');
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Journey'), leading: _started ? const SizedBox() : IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/my-trips'))),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const Spacer(),
          // Status icon
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: _started ? AppColors.ongoingBg : AppColors.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _started ? Icons.directions_car_filled : Icons.directions_car_outlined,
              size: 64,
              color: _started ? AppColors.ongoing : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 28),
          Text(_started ? 'Trip in Progress' : 'Ready to Start',
            style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 8),
          Text(
            _started ? 'Your location is being shared with admin. Tap "End Trip" when you arrive.'
                : 'Your declaration has been submitted. Press Start Journey to begin.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (_started) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(color: AppColors.ongoingBg, borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.ongoing, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text('Live tracking active', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ongoing)),
              ]),
            ),
          ],
          const Spacer(),
          if (!_started)
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: const Text('Start Journey'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.approved, minimumSize: const Size(double.infinity, 56)),
              onPressed: _loading ? null : _startJourney,
            )
          else
            ElevatedButton.icon(
              icon: const Icon(Icons.flag_rounded, size: 22),
              label: const Text('End Trip'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.rejected, minimumSize: const Size(double.infinity, 56)),
              onPressed: _loading ? null : _endJourney,
            ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}
