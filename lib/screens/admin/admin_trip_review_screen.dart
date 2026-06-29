import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:trip_manager/models/trip_model.dart';
import 'package:trip_manager/services/supabase_service.dart';
import 'package:trip_manager/services/weather_service.dart';
import 'package:trip_manager/theme/app_theme.dart';
import 'package:trip_manager/widgets/conditions_card.dart';

class AdminTripReviewScreen extends StatefulWidget {
  final String tripId;
  const AdminTripReviewScreen({super.key, required this.tripId});
  @override State<AdminTripReviewScreen> createState() => _AdminTripReviewScreenState();
}

class _AdminTripReviewScreenState extends State<AdminTripReviewScreen> {
  TripModel? _trip;
  bool _loading = true;
  bool _refreshingConditions = false;
  bool _deciding = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final data = await SupabaseService.getAllTrips();
    final tripData = data.firstWhere((t) => t['id'] == widget.tripId, orElse: () => {});
    setState(() { _trip = tripData.isNotEmpty ? TripModel.fromJson(tripData) : null; _loading = false; });
  }

  Future<void> _refreshConditions() async {
    if (_trip == null) return;
    setState(() => _refreshingConditions = true);
    try {
      final conditions = await WeatherService.fetchAllConditions(_trip!.fromLocation, _trip!.toLocation);
      conditions['trip_request_id'] = _trip!.id;
      await SupabaseService.upsertTripConditions(conditions);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error refreshing conditions: $e'), backgroundColor: AppColors.rejected),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshingConditions = false);
    }
  }

  Future<void> _approve() async {
    setState(() => _deciding = true);
    try {
      await SupabaseService.updateTripStatus(widget.tripId, 'approved', approvedBy: SupabaseService.currentUser!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trip approved!'), backgroundColor: AppColors.approved));
        context.go('/admin');
      }
    } finally { if (mounted) setState(() => _deciding = false); }
  }

  Future<void> _reject() async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Trip'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Provide an optional reason for rejection:'),
          const SizedBox(height: 12),
          TextField(
            controller: reasonCtrl,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Reason to reject the trip... (optional)', border: OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rejected),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deciding = true);
    try {
      await SupabaseService.updateTripStatus(widget.tripId, 'rejected',
        rejectionReason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trip rejected.'), backgroundColor: AppColors.rejected));
        context.go('/admin');
      }
    } finally { if (mounted) setState(() => _deciding = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/admin')),
        title: const Text('Review Trip'),
      ),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : _trip == null ? const Center(child: Text('Trip not found'))
          : Column(children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Requester info
                    if (_trip!.requestedByName != null)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          const Icon(Icons.person_outline, color: AppColors.primary, size: 20),
                          const SizedBox(width: 10),
                          Text('Requested by ', style: GoogleFonts.inter(fontSize: 13, color: AppColors.primary)),
                          Text(_trip!.requestedByName!, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
                        ]),
                      ),
                    const SizedBox(height: 20),
                    // Trip info
                    Text('Trip Information', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                      _row(Icons.trip_origin, 'From', _trip!.fromLocation),
                      _row(Icons.location_on, 'To', _trip!.toLocation),
                      _row(Icons.calendar_today, 'Date', DateFormat('dd MMMM yyyy').format(_trip!.tripDate)),
                      _row(Icons.access_time, 'Time', _trip!.tentativeTime),
                      if (_trip!.description != null && _trip!.description!.isNotEmpty)
                        _row(Icons.notes, 'Notes', _trip!.description!),
                      if (_trip!.coTravelers != null && _trip!.coTravelers!.isNotEmpty)
                        _row(Icons.people_outline, 'Co-Travelers', _trip!.coTravelers!),
                      _row(Icons.schedule, 'Requested', DateFormat('dd MMMM yyyy, HH:mm').format(_trip!.requestedAt)),
                    ]))),
                    const SizedBox(height: 24),
                    // Conditions
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Travel Conditions', style: Theme.of(context).textTheme.titleMedium),
                      TextButton.icon(
                        icon: _refreshingConditions
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.refresh, size: 16),
                        label: const Text('Re-fetch'),
                        onPressed: _refreshingConditions ? null : _refreshConditions,
                      ),
                    ]),
                    const SizedBox(height: 12),
                    if (_trip!.conditions != null)
                      ConditionsCard(conditions: _trip!.conditions!)
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppColors.pendingBg, borderRadius: BorderRadius.circular(12)),
                        child: Row(children: [
                          const Icon(Icons.cloud_off, color: AppColors.pending),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Conditions not fetched yet', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.pending)),
                            TextButton(onPressed: _refreshConditions, child: const Text('Fetch Now')),
                          ])),
                        ]),
                      ),
                    const SizedBox(height: 16),
                    // Risk warning if not safe
                    if (_trip!.conditions != null && !_trip!.conditions!.isSafeToTravel)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: AppColors.rejectedBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.rejected.withOpacity(0.4))),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Icon(Icons.warning_rounded, color: AppColors.rejected, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Text('This trip has been flagged as potentially unsafe based on current conditions. Review carefully before approving.',
                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.rejected, fontWeight: FontWeight.w500))),
                        ]),
                      ),
                  ]),
                ),
              ),
              // Decision buttons
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.cancel_outlined, color: AppColors.rejected),
                      label: const Text('Reject', style: TextStyle(color: AppColors.rejected)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.rejected), minimumSize: const Size(0, 52)),
                      onPressed: _deciding ? null : _reject,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.approved, minimumSize: const Size(0, 52)),
                      onPressed: _deciding ? null : _approve,
                    ),
                  ),
                ]),
              ),
            ]),
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Icon(icon, size: 16, color: AppColors.textSecondary),
      const SizedBox(width: 10),
      SizedBox(width: 70, child: Text(label, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary))),
      Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
    ]),
  );
}
