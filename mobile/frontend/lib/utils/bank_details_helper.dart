import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../screens/bank_details_screen.dart';
import '../theme/app_colors.dart';
import '../utils/app_logger.dart';

/// Helper function to check if user has bank details
/// Bank details are OPTIONAL - user can publish without them
/// Shows informational message if missing, but allows publishing
/// When bank details are missing, donations default to admin account
Future<bool> checkBankDetailsAndNavigate(BuildContext context) async {
  final userProvider = Provider.of<UserProvider>(context, listen: false);
  
  try {
    final bankDetails = await userProvider.getBankDetails();
    
    if (bankDetails == null) {
      // Bank details are optional - show info message but allow publishing
      final shouldAdd = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.warmBrown),
              const SizedBox(width: 8),
              const Text('Bank Details'),
            ],
          ),
          content: const Text(
            'Add your bank details so others can donate and support you. '
            'You can still publish without bank details - donations will be managed by the platform.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Continue Without',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warmBrown,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Add Bank Details'),
            ),
          ],
        ),
      );
      
      if (shouldAdd == true && context.mounted) {
        // Navigate to bank details screen
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const BankDetailsScreen(isFromUpload: true),
          ),
        );
      }
      
      // Always return true - bank details are optional
      // Publishing is allowed without bank details
      return true;
    }
    
    return true;
  } catch (e) {
    AppLogger.debug('Error checking bank details: $e');
    // Return true on error - don't block publishing
    return true;
  }
}
