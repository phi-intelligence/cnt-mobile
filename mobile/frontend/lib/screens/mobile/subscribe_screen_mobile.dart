import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/subscription.dart';
import '../../providers/subscription_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import 'billing_screen_mobile.dart';
import 'paystack_checkout_webview_screen.dart';

class SubscribeScreenMobile extends StatefulWidget {
  const SubscribeScreenMobile({super.key});

  @override
  State<SubscribeScreenMobile> createState() => _SubscribeScreenMobileState();
}

class _SubscribeScreenMobileState extends State<SubscribeScreenMobile> {
  bool _acceptTerms = false;
  bool _acceptPrivacy = false;
  bool _isCheckingOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<SubscriptionProvider>();
      provider.loadPlans();
      provider.refreshMe();
    });
  }

  Future<void> _handleSubscribe() async {
    if (!_acceptTerms || !_acceptPrivacy) {
      _showSnackBar(
        'Please accept the Terms of Service and Privacy Policy to continue.',
        isError: true,
      );
      return;
    }

    final provider = context.read<SubscriptionProvider>();
    if (provider.isEntitled) {
      _showSnackBar('You already have an active subscription.');
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BillingScreenMobile()),
      );
      return;
    }

    setState(() => _isCheckingOut = true);

    final authorizationUrl = await provider.startCheckout(
      acceptTerms: _acceptTerms,
      acceptPrivacy: _acceptPrivacy,
    );

    if (!mounted) return;

    if (authorizationUrl == null || authorizationUrl.isEmpty) {
      setState(() => _isCheckingOut = false);
      _showSnackBar(
        provider.error ?? 'Failed to start checkout. Please try again.',
        isError: true,
      );
      return;
    }

    final reference = await Navigator.push<String?>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PaystackCheckoutWebViewScreen(authorizationUrl: authorizationUrl),
      ),
    );

    if (!mounted) return;

    if (reference == null || reference.isEmpty) {
      setState(() => _isCheckingOut = false);
      _showSnackBar(
        'Payment was cancelled or incomplete.',
        isError: true,
      );
      return;
    }

    final success = await provider.completeCheckout(reference);
    if (!mounted) return;

    setState(() => _isCheckingOut = false);

    if (success) {
      _showSnackBar('Your subscription is now active.');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BillingScreenMobile()),
      );
    } else {
      _showSnackBar(
        provider.error ?? 'We could not verify your payment.',
        isError: true,
      );
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.errorMain : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubscriptionProvider>();
    final plan =
        provider.plans.isNotEmpty ? provider.plans.first : provider.me?.plan;
    final busy = provider.isLoading || _isCheckingOut;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: const Text('Subscribe to CNT'),
        backgroundColor: AppColors.backgroundPrimary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: busy && plan == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.warmBrown),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.large),
              child: plan != null
                  ? _buildPlanCard(plan, provider, busy)
                  : Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.large),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        provider.error ??
                            'No subscription plan is available right now.',
                        style: AppTypography.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
            ),
    );
  }

  Widget _buildPlanCard(
    SubscriptionPlan plan,
    SubscriptionProvider provider,
    bool busy,
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
          Text(
            plan.name,
            style: AppTypography.heading3.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.small),
          Text(
            '${plan.formattedAmount} / ${plan.intervalLabel}',
            style: AppTypography.heading2.copyWith(color: AppColors.warmBrown),
          ),
          if (plan.description != null && plan.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.medium),
            Text(
              plan.description!,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.large),
          Text(
            'Unlock creator tools, uploads, live streaming, and other premium features on the CNT platform.',
            style: AppTypography.body.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.large),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _acceptTerms,
            activeColor: AppColors.warmBrown,
            onChanged: busy
                ? null
                : (value) => setState(() => _acceptTerms = value ?? false),
            title: Text(
              'I accept the Terms of Service',
              style: AppTypography.body.copyWith(color: AppColors.textPrimary),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _acceptPrivacy,
            activeColor: AppColors.warmBrown,
            onChanged: busy
                ? null
                : (value) => setState(() => _acceptPrivacy = value ?? false),
            title: Text(
              'I accept the Privacy Policy',
              style: AppTypography.body.copyWith(color: AppColors.textPrimary),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: AppSpacing.large),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: busy
                  ? null
                  : provider.isEntitled
                      ? () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BillingScreenMobile(),
                            ),
                          );
                        }
                      : _handleSubscribe,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warmBrown,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      provider.isEntitled
                          ? 'View Billing'
                          : 'Subscribe with Paystack',
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
