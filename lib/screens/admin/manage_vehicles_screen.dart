import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:trip_manager/services/supabase_service.dart';
import 'package:trip_manager/theme/app_theme.dart';

class ManageVehiclesScreen extends StatefulWidget {
  const ManageVehiclesScreen({super.key});
  @override State<ManageVehiclesScreen> createState() => _ManageVehiclesScreenState();
}

class _ManageVehiclesScreenState extends State<ManageVehiclesScreen> {
  List<Map<String, dynamic>> _vehicles = [];
  List<Map<String, dynamic>> _filteredVehicles = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadVehicles();
    _searchCtrl.addListener(_filterVehicles);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await SupabaseService.getAllVehicles();
      setState(() {
        _vehicles = data;
        _filteredVehicles = data;
        _loading = false;
      });
      _filterVehicles();
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _filterVehicles() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredVehicles = _vehicles;
      } else {
        _filteredVehicles = _vehicles.where((v) {
          final number = (v['vehicle_number'] ?? '').toString().toLowerCase();
          final model = (v['model'] ?? '').toString().toLowerCase();
          return number.contains(query) || model.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _deleteVehicle(Map<String, dynamic> vehicle) async {
    final number = vehicle['vehicle_number'] ?? 'this vehicle';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: Text('Delete Vehicle', style: GoogleFonts.sora(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to permanently delete $number?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rejected),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await SupabaseService.deleteVehicle(vehicle['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle deleted successfully.'), backgroundColor: AppColors.approved),
        );
      }
      _loadVehicles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting vehicle: $e'),
            backgroundColor: AppColors.rejected,
          ),
        );
      }
    }
  }

  void _showEditVehicleDialog(Map<String, dynamic> vehicle) {
    final formKey = GlobalKey<FormState>();
    final numberCtrl = TextEditingController(text: vehicle['vehicle_number'] ?? '');
    final modelCtrl = TextEditingController(text: vehicle['model'] ?? '');
    final notesCtrl = TextEditingController(text: vehicle['technical_notes'] ?? '');
    DateTime? serviceDate = vehicle['last_service_on'] != null
        ? DateTime.tryParse(vehicle['last_service_on'].toString())
        : null;
    bool saving = false;
    String? dialogError;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              surfaceTintColor: Colors.transparent,
              title: Row(
                children: [
                  const Icon(Icons.edit_road_rounded, color: AppColors.primary, size: 24),
                  const SizedBox(width: 10),
                  Text('Edit Vehicle Details', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: numberCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Vehicle Number',
                          prefixIcon: Icon(Icons.confirmation_number_outlined),
                        ),
                        validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: modelCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Model / Type',
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () async {
                          final d = await showDatePicker(
                            context: dialogContext,
                            initialDate: serviceDate ?? DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
                            lastDate: DateTime.now(),
                          );
                          if (d != null) {
                            setDialogState(() => serviceDate = d);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textSecondary),
                              const SizedBox(width: 10),
                              Text(
                                serviceDate == null
                                    ? 'Last Service Date'
                                    : DateFormat('dd MMM yyyy').format(serviceDate!),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: serviceDate == null ? AppColors.textSecondary : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Technical Notes (Optional)',
                          alignLabelWithHint: true,
                        ),
                      ),
                      if (dialogError != null) ...[
                        const SizedBox(height: 12),
                        Text(dialogError!, style: GoogleFonts.inter(color: AppColors.rejected, fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() {
                            saving = true;
                            dialogError = null;
                          });
                          try {
                            final serviceStr = serviceDate != null
                                ? DateFormat('yyyy-MM-dd').format(serviceDate!)
                                : null;

                            await SupabaseService.updateVehicle(vehicle['id'], {
                              'vehicle_number': numberCtrl.text.trim().toUpperCase(),
                              'model': modelCtrl.text.trim(),
                              'last_service_on': serviceStr,
                              'technical_notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                            });

                            if (mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Vehicle updated successfully!'), backgroundColor: AppColors.approved),
                              );
                              _loadVehicles();
                            }
                          } catch (e) {
                            setDialogState(() {
                              saving = false;
                              dialogError = e.toString().replaceFirst('Exception: ', '');
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(100, 44),
                  ),
                  child: saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/admin')),
        title: const Text('Manage Vehicles'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search vehicle by number or model...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => _searchCtrl.clear())
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 56, color: AppColors.rejected),
                              const SizedBox(height: 12),
                              Text('Failed to load vehicles', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              Text(_error!, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                              const SizedBox(height: 20),
                              ElevatedButton(onPressed: _loadVehicles, child: const Text('Retry')),
                            ],
                          ),
                        ),
                      )
                    : _filteredVehicles.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.local_shipping_outlined, size: 56, color: AppColors.textHint),
                                const SizedBox(height: 12),
                                Text('No vehicles found', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadVehicles,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredVehicles.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                try {
                                  final vehicle = _filteredVehicles[index];
                                  final number = vehicle['vehicle_number'] ?? 'Unknown';
                                  final model = vehicle['model'] ?? 'Unknown Model';
                                  final isActive = vehicle['is_active'] ?? true;
                                  
                                  DateTime? parsedServiceDate;
                                  if (vehicle['last_service_on'] != null) {
                                    try {
                                      parsedServiceDate = DateTime.tryParse(vehicle['last_service_on'].toString());
                                    } catch (_) {}
                                  }
                                  final serviceDate = parsedServiceDate != null
                                      ? DateFormat('dd MMM yyyy').format(parsedServiceDate)
                                      : 'No service date';
                                  final notes = vehicle['technical_notes'] ?? 'No technical notes';

                                  return Card(
                                    key: ValueKey(vehicle['id'] ?? index.toString()),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                backgroundColor: AppColors.primarySurface,
                                                child: const Icon(
                                                  Icons.directions_car_rounded,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      number,
                                                      style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      model,
                                                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Divider(height: 24),
                                          Row(
                                            children: [
                                              const Icon(Icons.build_circle_outlined, size: 14, color: AppColors.textSecondary),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Last Serviced: $serviceDate',
                                                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Icon(Icons.info_outline, size: 14, color: AppColors.textSecondary),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  'Notes: $notes',
                                                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Divider(height: 24),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              OutlinedButton.icon(
                                                icon: const Icon(Icons.edit_rounded, size: 16),
                                                label: const Text('Edit Details'),
                                                style: OutlinedButton.styleFrom(
                                                  minimumSize: const Size(0, 40),
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                ),
                                                onPressed: () => _showEditVehicleDialog(vehicle),
                                              ),
                                              const SizedBox(width: 12),
                                              ElevatedButton.icon(
                                                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                                label: const Text('Delete'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.rejected,
                                                  minimumSize: const Size(0, 40),
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                ),
                                                onPressed: () => _deleteVehicle(vehicle),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                } catch (e, stack) {
                                  debugPrint('Error rendering vehicle card: $e\n$stack');
                                  return Card(
                                    color: AppColors.rejectedBg,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text('Error rendering vehicle: $e', style: GoogleFonts.inter(color: AppColors.rejected)),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
