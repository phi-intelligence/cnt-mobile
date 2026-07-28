import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Shared cream background + scrollable body for admin screens.
class AdminPageScaffold extends StatelessWidget {
  final Widget child;
  final Future<void> Function()? onRefresh;
  final EdgeInsetsGeometry? padding;

  const AdminPageScaffold({
    super.key,
    required this.child,
    this.onRefresh,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final body = padding != null
        ? Padding(padding: padding!, child: child)
        : child;

    if (onRefresh != null) {
      return Container(
        color: AppColors.backgroundPrimary,
        child: RefreshIndicator(
          onRefresh: onRefresh!,
          color: AppColors.warmBrown,
          child: body,
        ),
      );
    }

    return Container(
      color: AppColors.backgroundPrimary,
      child: body,
    );
  }
}

/// Scrollable error state for admin pages (avoids clipping on small screens).
class AdminErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const AdminErrorState({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: AppColors.errorMain),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: AppTypography.heading3.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warmBrown,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Draggable bottom sheet helper for admin detail views.
Future<T?> showAdminDetailSheet<T>({
  required BuildContext context,
  required Widget child,
  double initialChildSize = 0.55,
  double maxChildSize = 0.92,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cardBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      minChildSize: 0.35,
      maxChildSize: maxChildSize,
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: child,
      ),
    ),
  );
}
