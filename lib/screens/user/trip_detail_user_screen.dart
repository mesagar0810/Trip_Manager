import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:trip_manager/models/trip_model.dart';
import 'package:trip_manager/services/supabase_service.dart';
import 'package:trip_manager/theme/app_theme.dart';
import 'package:trip_manager/widgets/conditions_card.dart';
import 'package:trip_manager/widgets/status_badge.dart';

class TripDetailUserScreen extends StatefulWidget {
  final String tripId;
  const TripDetailUserScreen({super.key, required this.tripId});
  @override State<TripDetailUserScreen> createState() => _TripDetailUserScreenState();
}

class _TripDetailUserScreenState extends State<TripDetailUserScreen> {
  TripModel? _trip;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final data = await SupabaseService.getTripsForUser(SupabaseService.currentUser!.id);
    final tripData = data.firstWhere((t) => t['id'] == widget.tripId, orElse: () => {});
    setState(() { _trip = tripData.isNotEmpty ? TripModel.fromJson(tripData) : null; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/my-trips')),
        title: const Text('Trip Details'),
      ),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : _trip == null ? const Center(child: Text('Trip not found'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Header
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Trip #${_trip!.id.substring(0, 8).toUpperCase()}',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.5)),
                  StatusBadge(status: _trip!.status),
                ]),
                const SizedBox(height: 20),
                // Route
                _section('Route', [
                  _infoRow(Icons.trip_origin, 'From', _trip!.fromLocation),
                  _infoRow(Icons.location_on, 'To', _trip!.toLocation),
                  _infoRow(Icons.calendar_today, 'Date', DateFormat('dd MMMM yyyy').format(_trip!.tripDate)),
                  _infoRow(Icons.access_time, 'Time', _trip!.tentativeTime),
                  if (_trip!.description != null && _trip!.description!.isNotEmpty)
                    _infoRow(Icons.notes, 'Notes', _trip!.description!),
                  if (_trip!.coTravelers != null && _trip!.coTravelers!.isNotEmpty)
                    _infoRow(Icons.people_outline, 'Co-Travelers', _trip!.coTravelers!),
                  _infoRow(Icons.schedule, 'Requested', DateFormat('dd MMMM yyyy, HH:mm').format(_trip!.requestedAt)),
                ]),
                const SizedBox(height: 20),
                // Rejection reason if rejected
                if (_trip!.status == TripStatus.rejected && _trip!.rejectionReason != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.rejectedBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.rejected.withOpacity(0.3))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.cancel_outlined, color: AppColors.rejected, size: 18),
                        const SizedBox(width: 8),
                        Text('Rejection Reason', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.rejected)),
                      ]),
                      const SizedBox(height: 8),
                      Text(_trip!.rejectionReason!, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary)),
                    ]),
                  ),
                  const SizedBox(height: 20),
                ],
                // Conditions
                if (_trip!.conditions != null) ...[
                  Text('Travel Conditions', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  ConditionsCard(conditions: _trip!.conditions!),
                  const SizedBox(height: 20),
                ],
                // Assignment details (if approved and assigned)
                if (_trip!.assignment != null) ...[
                  _section('Assignment', [
                    if (_trip!.assignment!.vehicle != null) ...[
                      _infoRow(Icons.directions_car, 'Vehicle', _trip!.assignment!.vehicle!.vehicleNumber),
                      _infoRow(Icons.category, 'Model', _trip!.assignment!.vehicle!.model),
                      _infoRow(Icons.build_circle_outlined, 'Last Serviced', _trip!.assignment!.vehicle!.daysSinceService),
                    ],
                  ]),
                  const SizedBox(height: 20),
                ],
                // CTA actions
                if (_trip!.status == TripStatus.approved) ...[
                  if (_trip!.assignment == null)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.directions_car),
                      label: const Text('Select Your Vehicle'),
                      onPressed: () => context.go('/select-vehicle/${_trip!.id}'),
                    )
                  else if (_trip!.assignment!.declaration == null)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.assignment),
                      label: const Text('Fill Driver Declaration'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.pending),
                      onPressed: () => context.go('/declaration/${_trip!.assignment!.id}/${_trip!.id}'),
                    )
                  else if (_trip!.assignment!.declaration!.submitted)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start Journey'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.approved),
                      onPressed: () => context.go('/journey/${_trip!.id}/new'),
                    ),
                ],
                if (_trip!.status == TripStatus.rejected)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Submit New Request'),
                    onPressed: () => context.go('/request-trip'),
                  ),
              ]),
            ),
    );
  }

  Widget _section(String title, List<Widget> rows) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: Theme.of(context).textTheme.titleMedium),
    const SizedBox(height: 12),
    Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: rows))),
  ]);

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Icon(icon, size: 16, color: AppColors.textSecondary),
      const SizedBox(width: 10),
      SizedBox(width: 80, child: Text(label, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary))),
      Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
    ]),
  );
}
