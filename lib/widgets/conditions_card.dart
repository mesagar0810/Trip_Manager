import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trip_manager/models/trip_conditions_model.dart';
import 'package:trip_manager/theme/app_theme.dart';

class ConditionsCard extends StatelessWidget {
  final TripConditionsModel conditions;
  const ConditionsCard({super.key, required this.conditions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: conditions.isSafeToTravel ? AppColors.approvedBg : AppColors.rejectedBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: conditions.isSafeToTravel ? AppColors.approved : AppColors.rejected),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(conditions.isSafeToTravel ? Icons.check_circle : Icons.warning_rounded,
            color: conditions.isSafeToTravel ? AppColors.approved : AppColors.rejected, size: 20),
          const SizedBox(width: 8),
          Text(conditions.isSafeToTravel ? 'Safe to Travel' : 'Travel Risk Detected',
            style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 15,
              color: conditions.isSafeToTravel ? AppColors.approved : AppColors.rejected)),
        ]),
        const SizedBox(height: 14),
        _row(Icons.thermostat, 'Temperature', '${conditions.temperature}°C'),
        _row(_weatherIcon(conditions.weatherCondition), 'Weather', conditions.weatherLabel),
        _row(Icons.visibility, 'Visibility', conditions.visibilityLabel),
        _row(Icons.route, 'Road', conditions.roadConditionLabel),
        if (conditions.roadHazards != null && conditions.roadHazards!.isNotEmpty)
          _row(Icons.warning_amber, 'Hazards', conditions.roadHazards!),
        _row(Icons.update, 'Updated', _formatTime(conditions.fetchedAt)),
      ]),
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Icon(icon, size: 16, color: AppColors.textSecondary),
      const SizedBox(width: 8),
      Text('$label: ', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
      Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis)),
    ]),
  );

  IconData _weatherIcon(WeatherCondition c) {
    switch (c) {
      case WeatherCondition.clear: return Icons.wb_sunny;
      case WeatherCondition.rainy: return Icons.water_drop;
      case WeatherCondition.foggy: return Icons.blur_on;
      case WeatherCondition.stormy: return Icons.thunderstorm;
    }
  }

  String _formatTime(DateTime dt) {
    final localDt = DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second);
    final now = DateTime.now();
    final diff = now.difference(localDt);
    final minutes = diff.inMinutes;
    if (minutes <= 0) return 'Just now';
    if (minutes < 60) return '${minutes}m ago';
    final hours = diff.inHours;
    if (hours < 24) return '${hours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
