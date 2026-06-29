import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trip_manager/models/vehicle_model.dart';
import 'package:trip_manager/services/supabase_service.dart';
import 'package:trip_manager/theme/app_theme.dart';

class VehicleSelectScreen extends StatefulWidget {
  final String tripId;
  const VehicleSelectScreen({super.key, required this.tripId});
  @override State<VehicleSelectScreen> createState() => _VehicleSelectScreenState();
}

class _VehicleSelectScreenState extends State<VehicleSelectScreen> {
  List<VehicleModel> _vehicles = [];
  bool _loading = true;
  String? _selectedId;
  bool _submitting = false;
  final TextEditingController _dropdownCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _dropdownCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _dropdownCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
  }

  Future<void> _load() async {
    final data = await SupabaseService.getAvailableVehicles();
    setState(() {
      _vehicles = data.map((e) => VehicleModel.fromJson(e)).toList();
      _loading = false;
    });
  }

  List<VehicleModel> get _filteredVehicles {
    final query = _dropdownCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return _vehicles;

    // If the query exactly matches the selected vehicle's label, don't filter
    // so the user can still see all other options in the list below.
    if (_selectedId != null) {
      final selected = _vehicles.where((v) => v.id == _selectedId).firstOrNull;
      if (selected != null) {
        final label = '${selected.vehicleNumber} - ${selected.model}'.toLowerCase();
        if (query == label) {
          return _vehicles;
        }
      }
    }

    return _vehicles.where((v) {
      final number = v.vehicleNumber.toLowerCase();
      final model = v.model.toLowerCase();
      return number.contains(query) || model.contains(query);
    }).toList();
  }

  Future<void> _confirm() async {
    if (_selectedId == null) return;
    setState(() => _submitting = true);
    try {
      final uid = SupabaseService.currentUser!.id;
      final driverId = await SupabaseService.getDriverId(uid);
      if (driverId == null) throw Exception('Driver profile not found');
      final assignment = await SupabaseService.createAssignment(widget.tripId, driverId, _selectedId!);
      if (mounted) context.go('/declaration/${assignment['id']}/${widget.tripId}');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredVehicles;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/my-trips')),
        title: const Text('Select Vehicle'),
      ),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Text('Choose the vehicle you will be driving for this trip.',
                  style: Theme.of(context).textTheme.bodyMedium),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: DropdownMenu<String>(
                  controller: _dropdownCtrl,
                  width: MediaQuery.of(context).size.width - 48,
                  hintText: 'Search vehicle name or number...',
                  enableSearch: true,
                  enableFilter: true,
                  requestFocusOnTap: true,
                  leadingIcon: const Icon(Icons.search),
                  initialSelection: _selectedId,
                  inputDecorationTheme: Theme.of(context).inputDecorationTheme,
                  dropdownMenuEntries: _vehicles.map((v) {
                    return DropdownMenuEntry<String>(
                      value: v.id,
                      label: '${v.vehicleNumber} - ${v.model}',
                    );
                  }).toList(),
                  onSelected: (id) {
                    if (id != null) {
                      setState(() => _selectedId = id);
                    }
                  },
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.directions_car_filled_outlined, size: 56, color: AppColors.textHint),
                            const SizedBox(height: 12),
                            Text('No matching vehicles found',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final v = filtered[i];
                          final selected = _selectedId == v.id;
                          return GestureDetector(
                            key: ValueKey(v.id),
                            onTap: () {
                              setState(() {
                                _selectedId = v.id;
                                _dropdownCtrl.text = '${v.vehicleNumber} - ${v.model}';
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: selected ? AppColors.primarySurface : AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 2 : 1),
                              ),
                              child: Row(children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: selected ? AppColors.primary : AppColors.surfaceAlt, shape: BoxShape.circle),
                                  child: Icon(Icons.directions_car_filled, color: selected ? Colors.white : AppColors.textSecondary, size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(v.vehicleNumber, style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 15)),
                                  Text(v.model, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                                  Text('Last serviced: ${v.daysSinceService}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textHint)),
                                ])),
                                if (v.technicalNotes != null && v.technicalNotes!.isNotEmpty)
                                  Tooltip(message: v.technicalNotes!, child: const Icon(Icons.info_outline, size: 18, color: AppColors.textHint)),
                                if (selected) const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22),
                              ]),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: ElevatedButton(
                  onPressed: _selectedId == null || _submitting ? null : _confirm,
                  child: _submitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Confirm & Fill Declaration'),
                ),
              ),
            ]),
    );
  }
}
