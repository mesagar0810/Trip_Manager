import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:trip_manager/models/trip_model.dart';
import 'package:trip_manager/theme/app_theme.dart';
import 'package:trip_manager/widgets/status_badge.dart';

class TripCard extends StatelessWidget {
  final TripModel trip;
  final VoidCallback onTap;
  final Widget? trailing;

  const TripCard({super.key, required this.trip, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Trip #${trip.id.substring(0, 8).toUpperCase()}',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.5)),
              StatusBadge(status: trip.status),
            ]),
            const SizedBox(height: 12),
            _routeRow(),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.calendar_today, size: 14, color: AppColors.textHint),
              const SizedBox(width: 6),
              Text(DateFormat('dd MMM yyyy').format(trip.tripDate),
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(width: 12),
              const Icon(Icons.access_time, size: 14, color: AppColors.textHint),
              const SizedBox(width: 6),
              Text(trip.tentativeTime, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.schedule, size: 14, color: AppColors.textHint),
              const SizedBox(width: 6),
              Text(
                'Requested: ${DateFormat('dd MMM yyyy, HH:mm').format(trip.requestedAt)}',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              ),
            ]),
            if (trailing != null) ...[const SizedBox(height: 12), trailing!],
          ]),
        ),
      ),
    );
  }

  Widget _routeRow() {
    return Row(children: [
      Column(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
        Container(width: 2, height: 24, color: AppColors.border),
        Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(2))),
      ]),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(trip.fromLocation, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 14),
        Text(trip.toLocation, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
    ]);
  }
}
