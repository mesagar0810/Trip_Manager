import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:trip_manager/models/trip_model.dart';
import 'package:trip_manager/services/supabase_service.dart';
import 'package:trip_manager/theme/app_theme.dart';
import 'package:trip_manager/widgets/conditions_card.dart';
import 'package:trip_manager/widgets/status_badge.dart';

class TripDetailAdminScreen extends StatefulWidget {
  final String tripId;
  const TripDetailAdminScreen({super.key, required this.tripId});
  @override State<TripDetailAdminScreen> createState() => _TripDetailAdminScreenState();
}

class _TripDetailAdminScreenState extends State<TripDetailAdminScreen> {
  TripModel? _trip;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final data = await SupabaseService.getAllTrips();
    final tripData = data.firstWhere((t) => t['id'] == widget.tripId, orElse: () => {});
    setState(() { _trip = tripData.isNotEmpty ? TripModel.fromJson(tripData) : null; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/admin')),
        title: const Text('Trip Details'),
        actions: [
          if (_trip?.status == TripStatus.ongoing)
            TextButton.icon(
              icon: const Icon(Icons.location_on, color: AppColors.ongoing),
              label: const Text('Track', style: TextStyle(color: AppColors.ongoing)),
              onPressed: () => context.go('/admin/track/${_trip!.id}'),
            ),
        ],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : _trip == null ? const Center(child: Text('Trip not found'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Header
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Trip #${_trip!.id.substring(0, 8).toUpperCase()}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    if (_trip!.requestedByName != null)
                      Text('by ${_trip!.requestedByName!}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                  ]),
                  StatusBadge(status: _trip!.status),
                ]),
                const SizedBox(height: 20),

                _section('Route & Schedule', [
                  _row(Icons.trip_origin, 'From', _trip!.fromLocation),
                  _row(Icons.location_on, 'To', _trip!.toLocation),
                  _row(Icons.calendar_today, 'Date', DateFormat('dd MMMM yyyy').format(_trip!.tripDate)),
                  _row(Icons.access_time, 'Time', _trip!.tentativeTime),
                  if (_trip!.description != null && _trip!.description!.isNotEmpty)
                    _row(Icons.notes, 'Notes', _trip!.description!),
                  if (_trip!.coTravelers != null && _trip!.coTravelers!.isNotEmpty)
                    _row(Icons.people_outline, 'Co-Travelers', _trip!.coTravelers!),
                  _row(Icons.schedule, 'Requested', DateFormat('dd MMMM yyyy, HH:mm').format(_trip!.requestedAt)),
                ]),
                const SizedBox(height: 20),

                if (_trip!.status == TripStatus.rejected && _trip!.rejectionReason != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.rejectedBg, borderRadius: BorderRadius.circular(12)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.cancel_outlined, color: AppColors.rejected, size: 18),
                        const SizedBox(width: 8),
                        Text('Rejection Reason', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.rejected)),
                      ]),
                      const SizedBox(height: 8),
                      Text(_trip!.rejectionReason!, style: GoogleFonts.inter(fontSize: 14)),
                    ]),
                  ),
                  const SizedBox(height: 20),
                ],

                if (_trip!.conditions != null) ...[
                  Text('Travel Conditions', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  ConditionsCard(conditions: _trip!.conditions!),
                  const SizedBox(height: 20),
                ],

                if (_trip!.assignment != null) ...[
                  _section('Driver & Vehicle', [
                    if (_trip!.assignment!.driverName != null)
                      _row(Icons.person, 'Driver', _trip!.assignment!.driverName!),
                    if (_trip!.assignment!.vehicle != null) ...[
                      _row(Icons.directions_car, 'Vehicle', _trip!.assignment!.vehicle!.vehicleNumber),
                      _row(Icons.category, 'Model', _trip!.assignment!.vehicle!.model),
                      _row(Icons.build_circle_outlined, 'Last Service', _trip!.assignment!.vehicle!.daysSinceService),
                      if (_trip!.assignment!.vehicle!.technicalNotes != null)
                        _row(Icons.info_outline, 'Tech Notes', _trip!.assignment!.vehicle!.technicalNotes!),
                    ],
                  ]),
                  const SizedBox(height: 20),
                ],

                // Driver declaration summary
                if (_trip!.assignment?.declaration != null) ...[
                  Text('Driver Declaration', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                    _declarationRow('Valid Driving License', _trip!.assignment!.declaration!.hasValidLicence),
                    _declarationRow('Physically Fit', _trip!.assignment!.declaration!.isPhysicallyFit),
                    _declarationRow('Vehicle Roadworthy', _trip!.assignment!.declaration!.vehicleRoadworthy),
                    _declarationRow('Substance Free', _trip!.assignment!.declaration!.isSubstanceFree),
                    _declarationRow('Documents Available', _trip!.assignment!.declaration!.docsAvailable),
                    if (_trip!.assignment!.declaration!.submittedAt != null) ...[
                      const Divider(height: 20),
                      _row(Icons.schedule, 'Submitted', DateFormat('dd MMM, HH:mm').format(_trip!.assignment!.declaration!.submittedAt!)),
                    ],
                  ]))),
                  const SizedBox(height: 20),
                ],
              ]),
            ),
    );
  }

  Widget _section(String title, List<Widget> rows) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: Theme.of(context).textTheme.titleMedium),
    const SizedBox(height: 12),
    Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: rows))),
  ]);

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: AppColors.textSecondary),
      const SizedBox(width: 10),
      SizedBox(width: 90, child: Text(label, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary))),
      Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500))),
    ]),
  );

  Widget _declarationRow(String label, bool value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Icon(value ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 18, color: value ? AppColors.approved : AppColors.rejected),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 14))),
    ]),
  );
}
