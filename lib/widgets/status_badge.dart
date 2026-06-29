import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trip_manager/models/trip_model.dart';
import 'package:trip_manager/theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final TripStatus status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    switch (status) {
      case TripStatus.approved:
        bg = AppColors.approvedBg; fg = AppColors.approved; break;
      case TripStatus.rejected:
        bg = AppColors.rejectedBg; fg = AppColors.rejected; break;
      case TripStatus.pending:
        bg = AppColors.pendingBg; fg = AppColors.pending; break;
      case TripStatus.ongoing:
        bg = AppColors.ongoingBg; fg = AppColors.ongoing; break;
      case TripStatus.completed:
        bg = const Color(0xFFEEEEEE); fg = Colors.grey[700]!; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status.label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}
