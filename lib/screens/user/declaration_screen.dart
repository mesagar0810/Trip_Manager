import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:trip_manager/services/supabase_service.dart';
import 'package:trip_manager/theme/app_theme.dart';

class DeclarationScreen extends StatefulWidget {
  final String assignmentId;
  final String tripId;
  const DeclarationScreen({super.key, required this.assignmentId, required this.tripId});
  @override State<DeclarationScreen> createState() => _DeclarationScreenState();
}

class _DeclarationScreenState extends State<DeclarationScreen> {
  final Map<String, bool?> _answers = {
    'licence': null, 'fit': null, 'roadworthy': null, 'substance': null, 'docs': null,
  };
  bool _submitting = false;

  bool get _allAnswered => _answers.values.every((v) => v != null);
  bool get _allYes => _answers.values.every((v) => v == true);

  Future<void> _submit() async {
    if (!_allAnswered) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please answer all questions')));
      return;
    }
    if (!_allYes) {
      showDialog(context: context, builder: (_) => AlertDialog(
        title: const Text('Declaration Incomplete'),
        content: const Text('You must answer "Yes" to all questions to proceed with the trip. Please ensure all conditions are met.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ));
      return;
    }
    setState(() => _submitting = true);
    try {
      await SupabaseService.submitDeclaration({
        'id': const Uuid().v4(),
        'trip_assignment_id': widget.assignmentId,
        'has_valid_licence': _answers['licence'],
        'is_physically_fit': _answers['fit'],
        'vehicle_roadworthy': _answers['roadworthy'],
        'is_substance_free': _answers['substance'],
        'docs_available': _answers['docs'],
        'submitted': true,
        'submitted_at': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Declaration submitted! You can now start your journey.'), backgroundColor: AppColors.approved));
        context.go('/my-trips');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = [
      ('licence', 'Do you have a valid driving license for this vehicle?'),
      ('fit', 'Are you physically fit and rested to undertake this trip?'),
      ('roadworthy', 'Have you inspected the vehicle and found it roadworthy (brakes, lights, tyres, etc.)?'),
      ('substance', 'Are you free from alcohol, drugs, or any substance that may impair driving?'),
      ('docs', 'Are all required vehicle documents available and valid?'),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/my-trips')),
        title: const Text('Driver Declaration'),
      ),
      body: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text('This declaration must be completed truthfully before starting your journey. All questions must be answered "Yes" to proceed.',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.primary))),
                ]),
              ),
              const SizedBox(height: 24),
              ...questions.asMap().entries.map((entry) {
                final idx = entry.key;
                final (key, question) = entry.value;
                return _questionCard(idx + 1, key, question);
              }),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            if (!_allYes && _allAnswered)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: AppColors.rejectedBg, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.warning_rounded, color: AppColors.rejected, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text('All answers must be "Yes" to start the trip.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.rejected))),
                ]),
              ),
            ElevatedButton(
              onPressed: _allAnswered && !_submitting ? _submit : null,
              style: ElevatedButton.styleFrom(backgroundColor: _allYes ? AppColors.approved : AppColors.rejected.withOpacity(0.6)),
              child: _submitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Submit Declaration'),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _questionCard(int num, String key, String question) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _answers[key] == null ? AppColors.border : _answers[key]! ? AppColors.approved.withOpacity(0.5) : AppColors.rejected.withOpacity(0.5), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$num.  $question', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 12),
        Row(children: [
          _yesNoBtn(key, true, 'Yes'),
          const SizedBox(width: 10),
          _yesNoBtn(key, false, 'No'),
        ]),
      ]),
    );
  }

  Widget _yesNoBtn(String key, bool value, String label) {
    final selected = _answers[key] == value;
    final color = value ? AppColors.approved : AppColors.rejected;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _answers[key] = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.12) : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? color : AppColors.border, width: selected ? 1.5 : 1),
          ),
          alignment: Alignment.center,
          child: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: selected ? color : AppColors.textSecondary)),
        ),
      ),
    );
  }
}
