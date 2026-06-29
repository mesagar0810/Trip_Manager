import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:trip_manager/services/supabase_service.dart';
import 'package:trip_manager/theme/app_theme.dart';

class ManageDriversScreen extends StatefulWidget {
  const ManageDriversScreen({super.key});
  @override State<ManageDriversScreen> createState() => _ManageDriversScreenState();
}

class _ManageDriversScreenState extends State<ManageDriversScreen> {
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _filteredDrivers = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDrivers();
    _searchCtrl.addListener(_filterDrivers);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDrivers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await SupabaseService.getDetailedDrivers();
      setState(() {
        _drivers = data;
        _filteredDrivers = data;
        _loading = false;
      });
      _filterDrivers();
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _filterDrivers() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredDrivers = _drivers;
      } else {
        _filteredDrivers = _drivers.where((d) {
          final usersVal = d['users'];
          String username = '';
          if (usersVal is Map) {
            username = usersVal['user_name']?.toString() ?? '';
          } else if (usersVal is List && usersVal.isNotEmpty) {
            final first = usersVal[0];
            if (first is Map) {
              username = first['user_name']?.toString() ?? '';
            }
          }
          username = username.toLowerCase();
          final license = (d['license_number'] ?? '').toString().toLowerCase();
          return username.contains(query) || license.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _deleteDriver(Map<String, dynamic> driver) async {
    String username = 'this driver';
    final usersVal = driver['users'];
    if (usersVal is Map) {
      username = usersVal['user_name']?.toString() ?? 'this driver';
    } else if (usersVal is List && usersVal.isNotEmpty) {
      final first = usersVal[0];
      if (first is Map) {
        username = first['user_name']?.toString() ?? 'this driver';
      }
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: Text('Delete Driver', style: GoogleFonts.sora(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to permanently delete $username?'),
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
      await SupabaseService.deleteDriver(driver['id'], driver['user_id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver deleted successfully.'), backgroundColor: AppColors.approved),
        );
      }
      _loadDrivers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting driver: $e'),
            backgroundColor: AppColors.rejected,
          ),
        );
      }
    }
  }

  void _showEditDriverDialog(Map<String, dynamic> driver) {
    final formKey = GlobalKey<FormState>();
    String initialUsername = '';
    final usersVal = driver['users'];
    if (usersVal is Map) {
      initialUsername = usersVal['user_name']?.toString() ?? '';
    } else if (usersVal is List && usersVal.isNotEmpty) {
      final first = usersVal[0];
      if (first is Map) {
        initialUsername = first['user_name']?.toString() ?? '';
      }
    }
    final userCtrl = TextEditingController(text: initialUsername);
    final licenseCtrl = TextEditingController(text: driver['license_number'] ?? '');
    DateTime? licenseExpiry = driver['license_expiry'] != null
        ? DateTime.tryParse(driver['license_expiry'].toString())
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
                  Text('Edit Driver Details', style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: licenseCtrl,
                        decoration: const InputDecoration(
                          labelText: 'License Number',
                          prefixIcon: Icon(Icons.card_membership_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () async {
                          final d = await showDatePicker(
                            context: dialogContext,
                            initialDate: licenseExpiry ?? DateTime.now().add(const Duration(days: 365)),
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
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
                                    ? 'License Expiry Date'
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
                            final newUsername = userCtrl.text.trim();
                            String oldUsername = '';
                            final usersVal = driver['users'];
                            if (usersVal is Map) {
                              oldUsername = usersVal['user_name']?.toString() ?? '';
                            } else if (usersVal is List && usersVal.isNotEmpty) {
                              final first = usersVal[0];
                              if (first is Map) {
                                oldUsername = first['user_name']?.toString() ?? '';
                              }
                            }

                            // 1. Update username in users table if changed
                            if (newUsername != oldUsername) {
                              await SupabaseService.updateUser(driver['user_id'], {'user_name': newUsername});
                            }

                            // 2. Update driver properties
                            final expiryStr = licenseExpiry != null
                                ? DateFormat('yyyy-MM-dd').format(licenseExpiry!)
                                : null;

                            await SupabaseService.updateDriver(driver['id'], {
                              'license_number': licenseCtrl.text.trim().isEmpty ? null : licenseCtrl.text.trim(),
                              'license_expiry': expiryStr,
                            });

                            if (mounted) {
                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Driver updated successfully!'), backgroundColor: AppColors.approved),
                              );
                              _loadDrivers();
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
        title: const Text('Manage Drivers'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search driver by name or license...',
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
                              Text('Failed to load drivers', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              Text(_error!, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                              const SizedBox(height: 20),
                              ElevatedButton(onPressed: _loadDrivers, child: const Text('Retry')),
                            ],
                          ),
                        ),
                      )
                    : _filteredDrivers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.supervised_user_circle_rounded, size: 56, color: AppColors.textHint),
                                const SizedBox(height: 12),
                                Text('No drivers found', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadDrivers,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredDrivers.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                try {
                                  final driver = _filteredDrivers[index];
                                  String username = 'Unknown User';
                                  final usersVal = driver['users'];
                                  if (usersVal is Map) {
                                    username = usersVal['user_name']?.toString() ?? 'Unknown User';
                                  } else if (usersVal is List && usersVal.isNotEmpty) {
                                    final first = usersVal[0];
                                    if (first is Map) {
                                      username = first['user_name']?.toString() ?? 'Unknown User';
                                    }
                                  }
                                  final license = driver['license_number'] ?? 'No license registered';
                                  final isActive = driver['is_active'] ?? true;
                                  
                                  DateTime? parsedExpiry;
                                  if (driver['license_expiry'] != null) {
                                    try {
                                      parsedExpiry = DateTime.tryParse(driver['license_expiry'].toString());
                                    } catch (_) {}
                                  }
                                  final expiry = parsedExpiry != null
                                      ? DateFormat('dd MMM yyyy').format(parsedExpiry)
                                      : 'No expiry date';

                                  return Card(
                                    key: ValueKey(driver['id'] ?? index.toString()),
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
                                                  Icons.person_rounded,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  username,
                                                  style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Divider(height: 24),
                                          Row(
                                            children: [
                                              const Icon(Icons.card_membership, size: 14, color: AppColors.textSecondary),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  'License: $license',
                                                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Icon(Icons.event_note, size: 14, color: AppColors.textSecondary),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Expires: $expiry',
                                                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
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
                                                onPressed: () => _showEditDriverDialog(driver),
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
                                                onPressed: () => _deleteDriver(driver),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                } catch (e, stack) {
                                  debugPrint('Error rendering driver card: $e\n$stack');
                                  return Card(
                                    color: AppColors.rejectedBg,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text('Error rendering driver: $e', style: GoogleFonts.inter(color: AppColors.rejected)),
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
