import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/subscription.dart';
import '../../providers/subscription_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'subscribe_screen_mobile.dart';

class BillingScreenMobile extends StatefulWidget {
  const BillingScreenMobile({super.key});

  @override
  State<BillingScreenMobile> createState() => _BillingScreenMobileState();
}

class _BillingScreenMobileState extends State<BillingScreenMobile> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SubscriptionProvider>().refreshMe();
    });
  }

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel subscription?'),
        content: const Text(
          'Your subscription will remain active until the end of the current billing period.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep subscription'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel renewal'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final provider = context.read<SubscriptionProvider>();
    final success = await provider.cancelSubscription();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Subscription renewal canceled. Access continues until period end.'
              : provider.error ?? 'Failed to cancel subscription.',
        ),
        backgroundColor: success ? Colors.green : AppColors.errorMain,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not available';
    return DateFormat.yMMMMd().format(date.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubscriptionProvider>();
    final me = provider.me;
    final subscription = me?.subscription;
    final plan = me?.plan ?? subscription?.plan;
    final entitled = me?.entitled ?? false;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: const Text('Subscription & Billing'),
        backgroundColor: AppColors.backgroundPrimary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: provider.isLoading && me == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.warmBrown),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.large),
              child: _buildContent(me, subscription, plan, entitled, provider),
            ),
    );
  }

  Widget _buildContent(
    SubscriptionMe? me,
    SubscriptionInfo? subscription,
    SubscriptionPlan? plan,
    bool entitled,
    SubscriptionProvider provider,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.large),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: (entitled ? Colors.green : AppColors.errorMain)
                      .withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  entitled ? Icons.verified : Icons.lock_outline,
                  color: entitled ? Colors.green : AppColors.errorMain,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppSpacing.medium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entitled
                          ? 'Subscription active'
                          : 'No active subscription',
                      style: AppTypography.heading3.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entitled
                          ? 'You have access to premium CNT features.'
                          : 'Subscribe to unlock premium CNT features.',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.large),
          if (plan != null) ...[
            _buildInfoRow('Plan', plan.name),
            _buildInfoRow(
              'Price',
              '${plan.formattedAmount} / ${plan.intervalLabel}',
            ),
          ],
          if (subscription != null) ...[
            _buildInfoRow('Status', subscription.statusLabel),
            _buildInfoRow(
              'Current period ends',
              _formatDate(subscription.currentPeriodEnd),
            ),
          ],
          if (me?.enforcementEnabled == true)
            _buildInfoRow(
              'Enforcement',
              'Subscription required for premium features',
            ),
          const SizedBox(height: AppSpacing.large),
          if (!entitled)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: provider.isLoading
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SubscribeScreenMobile(),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warmBrown,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Subscribe'),
              ),
            )
          else if (subscription != null &&
              subscription.status == 'active' &&
              !subscription.cancelAtPeriodEnd)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: provider.isLoading ? null : _confirmCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.warmBrown,
                  side: const BorderSide(color: AppColors.warmBrown),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: provider.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Cancel renewal'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.medium),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.body.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
