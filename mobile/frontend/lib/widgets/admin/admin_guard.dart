import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Verifies admin access server-side before rendering admin-only UI.
/// Client-side `is_admin` flag alone is not trusted.
class AdminGuard extends StatefulWidget {
  final Widget child;
  final Widget? loading;
  final Widget? denied;

  const AdminGuard({
    super.key,
    required this.child,
    this.loading,
    this.denied,
  });

  @override
  State<AdminGuard> createState() => _AdminGuardState();
}

class _AdminGuardState extends State<AdminGuard> {
  bool _checking = true;
  bool _allowed = false;

  @override
  void initState() {
    super.initState();
    _verifyAdmin();
  }

  Future<void> _verifyAdmin() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAdmin) {
      setState(() {
        _checking = false;
        _allowed = false;
      });
      return;
    }

    try {
      // Server must enforce RBAC; this call fails with 403 if user is not admin.
      await ApiService().getAdminDashboard();
      if (!mounted) return;
      setState(() {
        _checking = false;
        _allowed = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _allowed = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return widget.loading ??
          const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
    }

    if (!_allowed) {
      return widget.denied ??
          Scaffold(
            appBar: AppBar(title: const Text('Access Denied')),
            body: Center(
              child: Text(
                'You do not have permission to access this area.',
                style: AppTypography.body.copyWith(color: AppColors.errorMain),
                textAlign: TextAlign.center,
              ),
            ),
          );
    }

    return widget.child;
  }
}
