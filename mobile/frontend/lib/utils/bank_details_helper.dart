import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/creator_provider.dart';
import '../services/donation_service.dart';
import '../screens/donation_modal.dart';
import '../config/environment.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/app_logger.dart';

/// Prefer hard creator gate before create; kept as a fallback if status is stale.
Future<bool> checkBankDetailsAndNavigate(BuildContext context) async {
  return context.read<CreatorProvider>().ensureReadyOrRedirect(context);
}

/// Check if recipient can accept donations via Paystack creator payout.
Future<bool> checkRecipientBankDetails(int recipientUserId) async {
  try {
    final donationService = DonationService();
    final eligibility =
        await donationService.eligibilityForUser(recipientUserId);
    return eligibility.acceptsDonations;
  } catch (e) {
    AppLogger.error('Error checking recipient donation eligibility', error: e);
    return false;
  }
}

Future<void> showRecipientBankDetailsMissingDialog(
  BuildContext context,
  String recipientName,
) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Donations Not Available'),
      content: Text(
        '$recipientName has not set up payouts yet, so donations are unavailable.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// Show donation modal after eligibility check.
Future<void> showDonationModalIfEligible(
  BuildContext context, {
  required int recipientUserId,
  required String recipientName,
  String? contentType,
  int? contentId,
}) async {
  final donationService = DonationService();
  var acceptsDonations = false;
  var resolvedRecipientId = recipientUserId;

  try {
    if (contentType != null && contentId != null) {
      final eligibility = await donationService.eligibilityForMedia(
        contentType: contentType,
        contentId: contentId,
      );
      acceptsDonations = eligibility.acceptsDonations;
      if (eligibility.recipientUserId > 0) {
        resolvedRecipientId = eligibility.recipientUserId;
      }
    } else {
      final eligibility =
          await donationService.eligibilityForUser(recipientUserId);
      acceptsDonations = eligibility.acceptsDonations;
    }
  } catch (e) {
    AppLogger.error('Error checking donation eligibility', error: e);
  }

  if (!acceptsDonations) {
    if (context.mounted) {
      await showRecipientBankDetailsMissingDialog(context, recipientName);
    }
    return;
  }

  if (!context.mounted) return;
  await showDialog(
    context: context,
    builder: (ctx) => DonationModal(
      recipientName: recipientName,
      recipientUserId: resolvedRecipientId,
      contentType: contentType,
      contentId: contentId,
    ),
  );
}

Future<void> showOrganizationDonationModal(BuildContext context) async {
  await showDonationModalIfEligible(
    context,
    recipientUserId: Environment.organizationRecipientUserId,
    recipientName: 'Christ New Tabernacle',
  );
}

/// Soft post-publish prompt when status may have been stale.
Future<void> showBankDetailsPromptAfterPublish(BuildContext context) async {
  await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.celebration, color: AppColors.successMain, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Content Submitted!', style: TextStyle(fontSize: 20)),
          ),
        ],
      ),
      content: const Text(
        'Your content was submitted. Set up Paystack payouts to receive donations.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(
            'Later',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop(true);
            context.read<CreatorProvider>().openPayoutSetup(context);
          },
          child: const Text('Set Up Payouts'),
        ),
      ],
    ),
  );
}
