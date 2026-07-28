import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/donation.dart';
import '../services/donation_service.dart';
import '../services/subscription_exceptions.dart';
import '../screens/mobile/paystack_checkout_webview_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class DonationModal extends StatefulWidget {
  final String recipientName;
  final int recipientUserId;
  final String? contentType;
  final int? contentId;

  const DonationModal({
    super.key,
    required this.recipientName,
    required this.recipientUserId,
    this.contentType,
    this.contentId,
  });

  @override
  State<DonationModal> createState() => _DonationModalState();
}

class _DonationModalState extends State<DonationModal> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final DonationService _donationService = DonationService();
  bool _isProcessing = false;
  double? _selectedPreset;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handleDonate() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text);
    final validationError = DonationAmountLimits.validateGhsAmount(amount);
    if (validationError != null) {
      _showSnackBar(validationError, isError: true);
      return;
    }

    final amountPesewas = ((amount ?? 0) * 100).round();
    if (amountPesewas <= 0) {
      _showSnackBar('Please enter a valid amount', isError: true);
      return;
    }

    setState(() => _isProcessing = true);

    final useMediaContext =
        widget.contentType != null && widget.contentId != null;

    try {
      final result = await _donationService.initialize(
        amountPesewas: amountPesewas,
        recipientUserId: useMediaContext ? null : widget.recipientUserId,
        contentType: useMediaContext ? widget.contentType : null,
        contentId: useMediaContext ? widget.contentId : null,
      );

      final authorizationUrl = result.authorizationUrl;
      if (authorizationUrl == null || authorizationUrl.isEmpty) {
        throw const DonationServiceException('Missing Paystack checkout URL');
      }

      if (!mounted) return;
      Navigator.of(context).pop();

      final reference = await Navigator.of(context).push<String?>(
        MaterialPageRoute(
          builder: (_) => PaystackCheckoutWebViewScreen(
            authorizationUrl: authorizationUrl,
            callbackPathContains: '/donation/callback',
          ),
        ),
      );

      if (reference == null || reference.isEmpty) return;

      final verify = await _donationService.verify(reference);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            verify.isSuccess
                ? 'Thank you for your donation!'
                : 'Donation status: ${verify.status}',
          ),
          backgroundColor:
              verify.isSuccess ? AppColors.successMain : AppColors.errorMain,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on SubscriptionRequiredException {
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) {
        _showSnackBar(e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.errorMain : AppColors.successMain,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _selectPreset(double value) {
    setState(() {
      _selectedPreset = value;
      _amountController.text = value.toStringAsFixed(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Donate to ${widget.recipientName}',
                style: AppTypography.heading3.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.small),
              Text(
                'Support this creator with a gift (GHS).',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.large),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: DonationAmountLimits.presetGhs.map((preset) {
                  final selected = _selectedPreset == preset;
                  return ChoiceChip(
                    label: Text('${preset.toStringAsFixed(0)} GHS'),
                    selected: selected,
                    onSelected: (_) => _selectPreset(preset),
                    selectedColor: AppColors.warmBrown.withValues(alpha: 0.2),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.medium),
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Amount (GHS)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  final amount = double.tryParse(value ?? '');
                  return DonationAmountLimits.validateGhsAmount(amount);
                },
                onChanged: (_) => setState(() => _selectedPreset = null),
              ),
              const SizedBox(height: AppSpacing.large),
              ElevatedButton(
                onPressed: _isProcessing ? null : _handleDonate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warmBrown,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Continue to Paystack'),
              ),
              TextButton(
                onPressed:
                    _isProcessing ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
