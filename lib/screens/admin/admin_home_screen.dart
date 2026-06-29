import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:trip_manager/models/trip_model.dart';
import 'package:trip_manager/services/supabase_service.dart';
import 'package:trip_manager/theme/app_theme.dart';
import 'package:trip_manager/widgets/trip_card.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});
  @override State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<TripModel> _trips = [];
  bool _loading = true;
  String? _error;
  final _tabs = ['Pending', 'Approved', 'Rejected', 'Ongoing', 'All'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await SupabaseService.getAllTrips();
      setState(() {
        _trips = data.map((e) => TripModel.fromJson(e)).toList();
        _loading = false;
      });
    } catch (e, stack) {
      debugPrint('Error loading admin trips: $e\n$stack');
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  List<TripModel> _filtered(String tab) {
    if (tab == 'All') return _trips;
    return _trips.where((t) => t.status.label == tab).toList();
  }

  @override
  Widget build(BuildContext context) {
    final ongoing = _trips.where((t) => t.status == TripStatus.ongoing).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          if (ongoing > 0)
            TextButton.icon(
              icon: const Icon(Icons.location_on, size: 16),
              label: Text('$ongoing Live'),
              style: TextButton.styleFrom(foregroundColor: AppColors.ongoing),
              onPressed: () => _tabController.animateTo(3),
            ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async { await SupabaseService.signOut(); if (mounted) context.go('/login'); },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
          unselectedLabelColor: AppColors.textSecondary,
          labelColor: AppColors.primary,
          indicatorColor: AppColors.primary,
          tabs: _tabs.map((t) {
            final count = t == 'All' ? _trips.length : _filtered(t).length;
            return Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(t),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: t == 'Pending' ? AppColors.pending : AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ],
            ]));
          }).toList(),
        ),
      ),
      body: _loading
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
                        Text('Failed to load trips', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _load,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(160, 44),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
              controller: _tabController,
              children: _tabs.map((tab) {
                final trips = _filtered(tab);
                if (trips.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.inbox_outlined, size: 56, color: AppColors.textHint),
                  const SizedBox(height: 12),
                  Text('No ${tab.toLowerCase()} trips', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary)),
                ]));
                return RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: trips.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final trip = trips[i];
                      Widget? trailing;
                      if (trip.status == TripStatus.pending) {
                        trailing = ElevatedButton(
                          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 20)),
                          onPressed: () => context.go('/admin/review/${trip.id}'),
                          child: const Text('Review & Decide'),
                        );
                      } else if (trip.status == TripStatus.ongoing) {
                        trailing = OutlinedButton.icon(
                          icon: const Icon(Icons.location_on, size: 16, color: AppColors.ongoing),
                          label: const Text('Track Live', style: TextStyle(color: AppColors.ongoing)),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 16),
                            side: const BorderSide(color: AppColors.ongoing),
                          ),
                          onPressed: () => context.go('/admin/track/${trip.id}'),
                        );
                      }
                      return TripCard(
                        trip: trip,
                        onTap: () {
                          if (trip.status == TripStatus.pending) {
                            context.go('/admin/review/${trip.id}');
                          } else {
                            context.go('/admin/trip-detail/${trip.id}');
                          }
                        },
                        trailing: trailing,
                      );
                    },
                  ),
                );
              }).toList(),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAdminActionsBottomSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _showAddAdminDialog() {
    final formKey = GlobalKey<FormState>();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool isCreating = false;
    String? errorMsg;

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
                  const Icon(Icons.admin_panel_settings_rounded, color: AppColors.primary, size: 24),
                  const SizedBox(width: 10),
                  Text('Add New Admin', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: userCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) {
                          final val = v?.trim() ?? '';
                          if (val.length < 3) return 'Min 3 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: passCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (v) => (v ?? '').length < 6 ? 'Min 6 characters' : null,
                      ),
                      if (errorMsg != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorMsg!,
                          style: GoogleFonts.inter(color: AppColors.rejected, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isCreating ? null : () => Navigator.pop(dialogContext),
                  child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  onPressed: isCreating
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() {
                            isCreating = true;
                            errorMsg = null;
                          });
                          try {
                            await SupabaseService.signUp(
                              userCtrl.text.trim(),
                              passCtrl.text,
                              'admin',
                            );
                            if (mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Admin created successfully!'),
                                  backgroundColor: AppColors.approved,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              isCreating = false;
                              errorMsg = e.toString().replaceFirst('Exception: ', '');
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(100, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isCreating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAdminActionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin Actions',
                  style: GoogleFonts.sora(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.4,
                  children: [
                    _actionTile(
                      icon: Icons.admin_panel_settings_rounded,
                      color: AppColors.primary,
                      label: 'Add Admin',
                      onTap: () {
                        Navigator.pop(context);
                        _showAddAdminDialog();
                      },
                    ),
                    _actionTile(
                      icon: Icons.drive_eta_rounded,
                      color: AppColors.approved,
                      label: 'Add Driver',
                      onTap: () {
                        Navigator.pop(context);
                        _showAddDriverDialog();
                      },
                    ),
                    _actionTile(
                      icon: Icons.local_shipping_rounded,
                      color: AppColors.accentDark,
                      label: 'Add Vehicle',
                      onTap: () {
                        Navigator.pop(context);
                        _showAddVehicleDialog();
                      },
                    ),
                    _actionTile(
                      icon: Icons.supervised_user_circle_rounded,
                      color: AppColors.primary,
                      label: 'Manage Drivers',
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/admin/drivers');
                      },
                    ),
                    _actionTile(
                      icon: Icons.car_rental_rounded,
                      color: AppColors.accentDark,
                      label: 'Manage Vehicles',
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/admin/vehicles');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: AppColors.surfaceAlt,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddDriverDialog() {
    final formKey = GlobalKey<FormState>();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final licenseCtrl = TextEditingController();
    DateTime? licenseExpiry;
    bool isCreating = false;
    String? errorMsg;

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
                  const Icon(Icons.drive_eta_rounded, color: AppColors.approved, size: 24),
                  const SizedBox(width: 10),
                  Text('Add New Driver', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                ],
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: userCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => (v?.trim().length ?? 0) < 3 ? 'Min 3 characters' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (v) => (v ?? '').length < 6 ? 'Min 6 characters' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: licenseCtrl,
                        decoration: const InputDecoration(
                          labelText: 'License Number (Optional)',
                          prefixIcon: Icon(Icons.card_membership_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () async {
                          final d = await showDatePicker(
                            context: dialogContext,
                            initialDate: DateTime.now().add(const Duration(days: 365)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 3650)),
                          );
                          if (d != null) {
                            setDialogState(() => licenseExpiry = d);
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
                                licenseExpiry == null
                                    ? 'License Expiry (Optional)'
                                    : DateFormat('dd MMM yyyy').format(licenseExpiry!),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: licenseExpiry == null ? AppColors.textSecondary : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (errorMsg != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorMsg!,
                          style: GoogleFonts.inter(color: AppColors.rejected, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isCreating ? null : () => Navigator.pop(dialogContext),
                  child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  onPressed: isCreating
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() {
                            isCreating = true;
                            errorMsg = null;
                          });
                          try {
                            final expiryStr = licenseExpiry != null
                                ? DateFormat('yyyy-MM-dd').format(licenseExpiry!)
                                : null;
                            await SupabaseService.createDriver(
                              userCtrl.text.trim(),
                              passCtrl.text,
                              licenseNumber: licenseCtrl.text.trim(),
                              licenseExpiry: expiryStr,
                            );
                            if (mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Driver created successfully!'),
                                  backgroundColor: AppColors.approved,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              isCreating = false;
                              errorMsg = e.toString().replaceFirst('Exception: ', '');
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.approved,
                    minimumSize: const Size(100, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isCreating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddVehicleDialog() {
    final formKey = GlobalKey<FormState>();
    final numberCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime? serviceDate;
    bool isCreating = false;
    String? errorMsg;

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
                  const Icon(Icons.local_shipping_rounded, color: AppColors.accentDark, size: 24),
                  const SizedBox(width: 10),
                  Text('Add New Vehicle', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
                          hintText: 'e.g. MH-12-AB-1234',
                        ),
                        validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: modelCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Model / Type',
                          prefixIcon: Icon(Icons.category_outlined),
                          hintText: 'e.g. Tata Nexon',
                        ),
                        validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () async {
                          final d = await showDatePicker(
                            context: dialogContext,
                            initialDate: DateTime.now(),
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
                                    ? 'Last Service Date (Optional)'
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
                      if (errorMsg != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          errorMsg!,
                          style: GoogleFonts.inter(color: AppColors.rejected, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isCreating ? null : () => Navigator.pop(dialogContext),
                  child: Text('Cancel', style: GoogleFonts.inter(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  onPressed: isCreating
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() {
                            isCreating = true;
                            errorMsg = null;
                          });
                          try {
                            final serviceStr = serviceDate != null
                                ? DateFormat('yyyy-MM-dd').format(serviceDate!)
                                : null;
                            await SupabaseService.createVehicle({
                              'vehicle_number': numberCtrl.text.trim().toUpperCase(),
                              'model': modelCtrl.text.trim(),
                              'last_service_on': serviceStr,
                              'technical_notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                              'is_active': true,
                            });
                            if (mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Vehicle created successfully!'),
                                  backgroundColor: AppColors.approved,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              isCreating = false;
                              errorMsg = e.toString().replaceFirst('Exception: ', '');
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(100, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isCreating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

}
