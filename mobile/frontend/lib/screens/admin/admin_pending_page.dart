import 'package:flutter/material.dart';

/// Deprecated: pending moderation is handled in [AdminContentPage].
/// Kept for backward compatibility if any deep links still reference this route.
@Deprecated('Use AdminContentPage with contentTabIndex: 0')
class AdminPendingPage extends StatelessWidget {
  final int initialTabIndex;

  const AdminPendingPage({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
