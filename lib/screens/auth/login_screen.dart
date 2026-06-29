import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:trip_manager/services/supabase_service.dart';
import 'package:trip_manager/theme/app_theme.dart';
import 'package:trip_manager/utils/app_router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await SupabaseService.signIn(_userCtrl.text.trim(), _passCtrl.text);
      if (res.user != null) {
        final profile = await SupabaseService.getUserProfile(res.user!.id);
        final role = profile?['role'] ?? 'user';
        AppRouter.userRole = role;
        if (mounted) context.go(role == 'admin' ? '/admin' : '/home');
      }
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() => _error = msg.contains('deactivated') ? msg : 'Invalid username or password');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.local_shipping_rounded, color: AppColors.accent, size: 36),
                            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.3),
                            const SizedBox(height: 24),
                            Text('Trip\nManager', style: GoogleFonts.sora(fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1))
                                .animate().fadeIn(delay: 300.ms).slideX(begin: -0.2),
                            const SizedBox(height: 8),
                            Text('Fleet management, simplified.', style: GoogleFonts.inter(fontSize: 15, color: Colors.white54))
                                .animate().fadeIn(delay: 400.ms),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                          ),
                          padding: const EdgeInsets.all(28),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text('Sign in', style: Theme.of(context).textTheme.displayMedium),
                                const SizedBox(height: 6),
                                Text('Enter your credentials to continue', style: Theme.of(context).textTheme.bodyMedium),
                                const SizedBox(height: 28),
                                TextFormField(
                                  controller: _userCtrl,
                                  decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline)),
                                  validator: (v) => (v ?? '').isEmpty ? 'Enter username' : null,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _passCtrl,
                                  obscureText: _obscure,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                      onPressed: () => setState(() => _obscure = !_obscure),
                                    ),
                                  ),
                                  validator: (v) => (v ?? '').length < 6 ? 'Min 6 characters' : null,
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: AppColors.rejectedBg, borderRadius: BorderRadius.circular(10)),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline, color: AppColors.rejected, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(_error!, style: GoogleFonts.inter(color: AppColors.rejected, fontSize: 13)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: _loading ? null : _login,
                                  child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Text('Sign In'),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text("Don't have an account? ", style: Theme.of(context).textTheme.bodyMedium),
                                    GestureDetector(
                                      onTap: () => context.go('/signup'),
                                      child: Text('Create one', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
