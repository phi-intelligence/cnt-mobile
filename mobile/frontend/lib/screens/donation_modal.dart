import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../services/donation_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/security_hardening.dart';
import '../utils/api_error_utils.dart';

class DonationModal extends StatefulWidget {
  final String recipientName;
  final int recipientUserId;
  
  const DonationModal({
    super.key,
    required this.recipientName,
    required this.recipientUserId,
  });

  @override
  State<DonationModal> createState() => _DonationModalState();
}

class _DonationModalState extends State<DonationModal> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final DonationService _donationService = DonationService();
  bool _isProcessing = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handleDonate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount < 1 || amount > 10000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an amount between \$1 and \$10,000'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Create payment intent
      final paymentIntent = await _donationService.createPaymentIntent(
        recipientUserId: widget.recipientUserId,
        amount: amount,
        currency: 'USD',
      );

      // Set Stripe publishable key from backend response
      if (paymentIntent.containsKey('publishable_key')) {
        Stripe.publishableKey = paymentIntent['publishable_key'];
      }

      // Initialize Stripe payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntent['client_secret'],
          merchantDisplayName: 'CNT Media Platform',
          customerId: paymentIntent['customer_id'],
          customerEphemeralKeySecret: paymentIntent['ephemeral_key'],
          style: ThemeMode.system,
          appearance: PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: AppColors.warmBrown,
            ),
          ),
        ),
      );

      // Present payment sheet
      await Stripe.instance.presentPaymentSheet();

      // Payment successful, confirm with backend
      await _donationService.confirmDonation(paymentIntent['payment_intent_id']);

      if (mounted) {
        Navigator.of(context).pop(true); // Return success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Donation of \$${amount.toStringAsFixed(2)} sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on StripeException catch (e) {
      if (mounted) {
        // User cancelled or error occurred
        if (e.error.code != FailureCode.Canceled) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment failed: ${e.error.message ?? e.error.code.name}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Donation failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    
    return SecureScreen(
      child: Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
          maxWidth: 400,
      ),
      child: Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.large,
            right: AppSpacing.large,
            top: AppSpacing.large,
            bottom: AppSpacing.large + bottomPadding,
          ),
        child: Form(
          key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                // Header row
              Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Expanded(
                      child: Text(
                    'Donate to ${widget.recipientName}',
                    style: AppTypography.heading3.copyWith(
                      fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                  ),
                ],
              ),
                const SizedBox(height: AppSpacing.medium),
              
                // Scrollable content
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
              // Amount field
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount (USD)',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: AppColors.backgroundSecondary,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
                        const SizedBox(height: AppSpacing.small),
              
              // Payment info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warmBrown.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.warmBrown.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock, size: 16, color: AppColors.warmBrown),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Secure payment powered by Stripe',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.medium),
              
                // Donate button (always visible at bottom)
              ElevatedButton(
                onPressed: _isProcessing ? null : _handleDonate,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppColors.primaryMain,
                  foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Donate',
                        style: AppTypography.body.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
                ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}

