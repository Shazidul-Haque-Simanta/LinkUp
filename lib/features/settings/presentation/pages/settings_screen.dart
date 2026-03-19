import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project_v2/core/theme/theme_provider.dart';
import 'package:project_v2/services/firebase_service.dart';
import 'package:project_v2/models/user_model.dart';
import 'package:project_v2/features/auth/presentation/pages/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _pushNotifications = true;
  bool _emailNotifications = false;
  bool _isLoggingOut = false;

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return '?';
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: Text('Log Out', style: TextStyle(color: Theme.of(context).colorScheme.onError)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoggingOut = true);
    try {
      await _firebaseService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoggingOut = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Log out failed: $e')),
        );
      }
    }
  }

  void _showEditProfileDialog(UserModel user) {
    final nameCtrl = TextEditingController(text: user.name);
    final uniCtrl = TextEditingController(text: user.university);
    final deptCtrl = TextEditingController(text: user.department);
    final semCtrl = TextEditingController(text: user.semester.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(nameCtrl, 'Full Name', Icons.person_outline),
              const SizedBox(height: 12),
              _dialogField(uniCtrl, 'University', Icons.school_outlined),
              const SizedBox(height: 12),
              _dialogField(deptCtrl, 'Department', Icons.book_outlined),
              const SizedBox(height: 12),
              _dialogField(semCtrl, 'Semester', Icons.access_time, inputType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              if (newName.isEmpty) return;

              final nav = Navigator.of(ctx);
              final scaffoldMsg = ScaffoldMessenger.of(context);

              try {
                await _firebaseService.updateUserProfile(user.uid, {
                  'name': newName,
                  'university': uniCtrl.text.trim(),
                  'department': deptCtrl.text.trim(),
                  'semester': int.tryParse(semCtrl.text.trim()) ?? user.semester,
                });
                nav.pop();
                if (mounted) setState(() {}); // Trigger FutureBuilder re-fetch
                scaffoldMsg.showSnackBar(
                  const SnackBar(content: Text('Profile updated successfully!')),
                );
              } catch (e) {
                scaffoldMsg.showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: Text('Save', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (ctx) => const _ChangePasswordDialog(),
    );
  }

  void _showAboutDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: SingleChildScrollView(child: Text(content, style: TextStyle(height: 1.6, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8)))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currentUser = _firebaseService.currentUser;
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark || (themeMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: TextStyle(color: theme.textTheme.titleMedium?.color, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
      ),
      body: currentUser == null
          ? const Center(child: Text('Not logged in'))
          : FutureBuilder<UserModel?>(
              future: _firebaseService.getUserProfile(currentUser.uid),
              builder: (context, snapshot) {
                final user = snapshot.data;
                final name = user?.name ?? currentUser.email?.split('@')[0] ?? 'User';
                final email = user?.email ?? currentUser.email ?? '';
                final initial = _initials(name);

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Profile Header ─────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              child: Text(
                                initial,
                                style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
                                  Text(email, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 12)),
                                  if (user != null && user.department.isNotEmpty)
                                    Text(
                                      '${user.department} · Semester ${user.semester}',
                                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 11),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),

                      // ── Account Section ────────────────────────────────
                      _sectionHeader('ACCOUNT'),
                      _settingsItem(
                        Icons.person_outline,
                        'Edit Profile',
                        color: Colors.purple[800]!,
                        onTap: user != null ? () => _showEditProfileDialog(user) : null,
                      ),
                      _settingsItem(
                        Icons.lock_outline,
                        'Change Password',
                        color: Colors.amber[600]!,
                        onTap: _showChangePasswordDialog,
                      ),

                      // ── Preferences Section ────────────────────────────
                      _sectionHeader('PREFERENCES'),
                      _toggleItem(
                        Icons.dark_mode_outlined,
                        'Dark Mode',
                        isDark,
                        (v) => ref.read(themeProvider.notifier).toggleTheme(v),
                        color: Colors.deepPurple[300]!,
                      ),
                      _toggleItem(
                        Icons.notifications_none,
                        'Push Notifications',
                        _pushNotifications,
                        (v) => setState(() => _pushNotifications = v),
                        color: Colors.orange,
                      ),
                      _toggleItem(
                        Icons.mail_outline,
                        'Email Notifications',
                        _emailNotifications,
                        (v) => setState(() => _emailNotifications = v),
                        color: Colors.blue,
                      ),

                      // ── About Section ──────────────────────────────────
                      _sectionHeader('ABOUT'),
                      _settingsItem(
                        Icons.assignment_outlined,
                        'Terms of Service',
                        color: Colors.red[300]!,
                        onTap: () => _showAboutDialog(
                          'Terms of Service',
                          'By using this app, you agree to our terms. You must be a student or educator to use this platform. '
                          'All uploaded resources should be original or properly licensed. Do not share copyrighted material without permission. '
                          'We reserve the right to remove content that violates these terms.\n\n'
                          'This application is intended for educational purposes only. Users are responsible for the content they upload.',
                        ),
                      ),
                      _settingsItem(
                        Icons.security_outlined,
                        'Privacy Policy',
                        color: Colors.teal,
                        onTap: () => _showAboutDialog(
                          'Privacy Policy',
                          'We collect and store user information to provide our services. '
                          'Your data is stored securely using Firebase. We do not sell your personal information to third parties.\n\n'
                          'Data we collect: Name, email, university information, uploaded resources, and bookmarks.\n\n'
                          'You can delete your account and all associated data at any time by contacting us.',
                        ),
                      ),
                      _infoItem(Icons.info_outline, 'App Version 1.0.0', color: Colors.blue[400]!),
                      const SizedBox(height: 40),

                      // ── Log Out ────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: OutlinedButton(
                          onPressed: _isLoggingOut ? null : _logout,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoggingOut
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.logout, color: Colors.redAccent, size: 20),
                                    SizedBox(width: 8),
                                    Text('Log Out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // ── Widget Helpers ────────────────────────────────────────────────────────

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        title,
        style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0),
      ),
    );
  }

  Widget _settingsItem(IconData icon, String title, {required Color color, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(title, style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyLarge?.color)),
      trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3), size: 20),
      onTap: onTap,
    );
  }

  Widget _toggleItem(IconData icon, String title, bool value, Function(bool) onChanged, {required Color color}) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(title, style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyLarge?.color)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Theme.of(context).colorScheme.onPrimary,
        activeColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _infoItem(IconData icon, String title, {required Color color}) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(title, style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyLarge?.color)),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String label, IconData icon, {TextInputType inputType = TextInputType.text}) {
    final theme = Theme.of(context);
    return TextField(
      controller: ctrl,
      keyboardType: inputType,
      style: TextStyle(color: theme.textTheme.bodyLarge?.color),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color),
        prefixIcon: Icon(icon, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainer,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.colorScheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Change Password Dialog — full StatefulWidget so state survives rebuilds
// ────────────────────────────────────────────────────────────────────────────

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_newCtrl.text != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }
    if (_newCtrl.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final nav = Navigator.of(context);
    final scaffoldMsg = ScaffoldMessenger.of(context);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) throw Exception('Not logged in');

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentCtrl.text,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newCtrl.text);

      nav.pop();
      scaffoldMsg.showSnackBar(
        const SnackBar(content: Text('Password changed successfully!')),
      );
    } on FirebaseAuthException catch (e) {
      String msg = 'Failed to change password';
      if (e.code == 'wrong-password') msg = 'Current password is incorrect';
      if (e.code == 'weak-password') msg = 'New password is too weak';
      scaffoldMsg.showSnackBar(SnackBar(content: Text(msg)));
      setState(() => _isLoading = false);
    } catch (e) {
      scaffoldMsg.showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _isLoading = false);
    }
  }

  Widget _field(TextEditingController ctrl, String label, bool obscure, VoidCallback toggle) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
        prefixIcon: Icon(Icons.lock_outline, size: 20, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
          onPressed: toggle,
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainer,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _field(_currentCtrl, 'Current Password', _obscureCurrent, () => setState(() => _obscureCurrent = !_obscureCurrent)),
          const SizedBox(height: 12),
          _field(_newCtrl, 'New Password', _obscureNew, () => setState(() => _obscureNew = !_obscureNew)),
          const SizedBox(height: 12),
          _field(_confirmCtrl, 'Confirm New Password', _obscureNew, () {}),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.onPrimary))
              : Text('Update', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
        ),
      ],
    );
  }
}
