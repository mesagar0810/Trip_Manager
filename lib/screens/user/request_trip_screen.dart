import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:trip_manager/services/location_service.dart';
import 'package:trip_manager/services/supabase_service.dart';
import 'package:trip_manager/services/weather_service.dart';
import 'package:trip_manager/theme/app_theme.dart';

class RequestTripScreen extends StatefulWidget {
  const RequestTripScreen({super.key});
  @override State<RequestTripScreen> createState() => _RequestTripScreenState();
}

class _RequestTripScreenState extends State<RequestTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _coTravelersCtrl = TextEditingController();
  final _fromFocusNode = FocusNode();
  final _toFocusNode = FocusNode();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _loading = false;

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _descCtrl.dispose();
    _coTravelersCtrl.dispose();
    _fromFocusNode.dispose();
    _toFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select date and time')));
      return;
    }
    setState(() => _loading = true);
    try {
      final uid = SupabaseService.currentUser!.id;
      final tripId = const Uuid().v4();

      // 1. Create trip
      await SupabaseService.createTrip({
        'id': tripId,
        'requested_by': uid,
        'from_location': _fromCtrl.text.trim(),
        'to_location': _toCtrl.text.trim(),
        'trip_date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
        'tentative_time': _selectedTime!.format(context),
        'description': _descCtrl.text.trim(),
        'co_travelers': _coTravelersCtrl.text.trim().isEmpty ? null : _coTravelersCtrl.text.trim(),
        'status': 'pending',
        'requested_at': DateTime.now().toIso8601String(),
      });

      // 2. Auto-fetch conditions in background
      final conditions = await WeatherService.fetchAllConditions(
        _fromCtrl.text.trim(), _toCtrl.text.trim());
      conditions['trip_request_id'] = tripId;
      await SupabaseService.upsertTripConditions(conditions);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip request submitted!'), backgroundColor: AppColors.approved));
        context.go('/my-trips');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showCupertinoTimePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 280,
          color: AppColors.surface,
          child: Column(
            children: [
              Container(
                color: AppColors.surfaceAlt,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Text(
                      'Select Time',
                      style: GoogleFonts.sora(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary, decoration: TextDecoration.none),
                    ),
                    TextButton(
                      child: Text('Done', style: GoogleFonts.inter(color: AppColors.primary, fontWeight: FontWeight.w600)),
                      onPressed: () {
                        if (_selectedTime == null) {
                          setState(() {
                            _selectedTime = TimeOfDay.now();
                          });
                        }
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: DateTime(
                    DateTime.now().year,
                    DateTime.now().month,
                    DateTime.now().day,
                    _selectedTime?.hour ?? DateTime.now().hour,
                    _selectedTime?.minute ?? DateTime.now().minute,
                  ),
                  onDateTimeChanged: (DateTime newDateTime) {
                    setState(() {
                      _selectedTime = TimeOfDay(hour: newDateTime.hour, minute: newDateTime.minute);
                    });
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request Trip'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/home'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionLabel('Route Details'),
            const SizedBox(height: 12),
            RawAutocomplete<String>(
              textEditingController: _fromCtrl,
              focusNode: _fromFocusNode,
              optionsBuilder: (TextEditingValue textEditingValue) async {
                if (textEditingValue.text.isEmpty || !_fromFocusNode.hasFocus) {
                  return const Iterable<String>.empty();
                }
                return await LocationService.getPlaceSuggestions(textEditingValue.text);
              },
              onSelected: (String selection) {
                _fromCtrl.text = selection;
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(labelText: 'Starting Point', prefixIcon: Icon(Icons.trip_origin, color: AppColors.primary)),
                  validator: (v) => (v ?? '').isEmpty ? 'Required' : null,
                  onFieldSubmitted: (_) => onFieldSubmitted(),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return _autocompleteOptionsView(context, onSelected, options);
              },
            ),
            const SizedBox(height: 12),
            RawAutocomplete<String>(
              textEditingController: _toCtrl,
              focusNode: _toFocusNode,
              optionsBuilder: (TextEditingValue textEditingValue) async {
                if (textEditingValue.text.isEmpty || !_toFocusNode.hasFocus) {
                  return const Iterable<String>.empty();
                }
                return await LocationService.getPlaceSuggestions(textEditingValue.text);
              },
              onSelected: (String selection) {
                _toCtrl.text = selection;
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(labelText: 'Destination', prefixIcon: Icon(Icons.location_on, color: AppColors.accent)),
                  validator: (v) => (v ?? '').isEmpty ? 'Required' : null,
                  onFieldSubmitted: (_) => onFieldSubmitted(),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return _autocompleteOptionsView(context, onSelected, options);
              },
            ),
            const SizedBox(height: 24),
            _sectionLabel('Date & Time'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _dateTimePicker(
                label: _selectedDate == null ? 'Select Date' : DateFormat('dd MMM yyyy').format(_selectedDate!),
                icon: Icons.calendar_today,
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (d != null) setState(() => _selectedDate = d);
                },
              )),
              const SizedBox(width: 12),
              Expanded(child: _dateTimePicker(
                label: _selectedTime == null ? 'Select Time' : _selectedTime!.format(context),
                icon: Icons.access_time,
                onTap: _showCupertinoTimePicker,
              )),
            ]),
            const SizedBox(height: 24),
            _sectionLabel('Description (Optional)'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Purpose or notes about the trip', alignLabelWithHint: true),
            ),
            const SizedBox(height: 24),
            _sectionLabel('Co-Travelers'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _coTravelersCtrl,
              decoration: const InputDecoration(
                labelText: 'Names of co-travelers (e.g. Ramesh, Suresh)',
                prefixIcon: Icon(Icons.people_outline, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.cloud_download_outlined, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Weather and road conditions will be fetched automatically on submission.',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.primary))),
              ]),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                SizedBox(width: 10),
                Text('Fetching conditions...'),
              ]) : const Text('Submit Request'),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text, style: Theme.of(context).textTheme.titleMedium);

  Widget _dateTimePicker({required String label, required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Flexible(child: Text(label, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }

  Widget _autocompleteOptionsView(
    BuildContext context,
    AutocompleteOnSelected<String> onSelected,
    Iterable<String> options,
  ) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        color: AppColors.surface,
        child: Container(
          width: MediaQuery.of(context).size.width - 48,
          constraints: const BoxConstraints(maxHeight: 220),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: options.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.border),
            itemBuilder: (BuildContext context, int index) {
              final String option = options.elementAt(index);
              return InkWell(
                onTap: () => onSelected(option),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: AppColors.textSecondary, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          option,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
