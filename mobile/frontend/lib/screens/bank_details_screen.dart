import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/shared/pill_text_field.dart';
import '../utils/app_logger.dart';

class BankDetailsScreen extends StatefulWidget {
  final bool isFromUpload;
  
  const BankDetailsScreen({super.key, this.isFromUpload = false});

  @override
  State<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends State<BankDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountNumberController = TextEditingController();
  final _ifscCodeController = TextEditingController();
  final _swiftCodeController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountHolderNameController = TextEditingController();
  final _branchNameController = TextEditingController();
  bool _isLoading = false;
  bool _hasExistingDetails = false;

  @override
  void initState() {
    super.initState();
    _loadBankDetails();
  }

  Future<void> _loadBankDetails() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    setState(() => _isLoading = true);
    
    try {
      final details = await userProvider.getBankDetails();
      if (details != null) {
        setState(() {
          _hasExistingDetails = true;
          // Don't load account number for security
          _ifscCodeController.text = details['ifsc_code'] ?? '';
          _swiftCodeController.text = details['swift_code'] ?? '';
          _bankNameController.text = details['bank_name'] ?? '';
          _accountHolderNameController.text = details['account_holder_name'] ?? '';
          _branchNameController.text = details['branch_name'] ?? '';
        });
      }
    } catch (e) {
      AppLogger.debug('Error loading bank details: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    _ifscCodeController.dispose();
    _swiftCodeController.dispose();
    _bankNameController.dispose();
    _accountHolderNameController.dispose();
    _branchNameController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    try {
      final success = await userProvider.updateBankDetails({
        'account_number': _accountNumberController.text.trim(),
        'ifsc_code': _ifscCodeController.text.trim(),
        'swift_code': _swiftCodeController.text.trim().isEmpty ? null : _swiftCodeController.text.trim(),
        'bank_name': _bankNameController.text.trim(),
        'account_holder_name': _accountHolderNameController.text.trim(),
        'branch_name': _branchNameController.text.trim(),
      });

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Bank details saved successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          
          if (widget.isFromUpload) {
            Navigator.of(context).pop(true); // Return true to indicate success
          } else {
            Navigator.of(context).pop();
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(userProvider.error ?? 'Failed to save bank details'),
              backgroundColor: AppColors.errorMain,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8), // Cream background
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F0E8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Bank Details',
          style: AppTypography.heading3.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading && !_hasExistingDetails
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.warmBrown,
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(AppSpacing.large),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.warmBrown,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.warmBrown.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.account_balance,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _hasExistingDetails ? 'Update Bank Details' : 'Add Bank Details',
                            style: AppTypography.heading3.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your bank details are encrypted and secure',
                            style: AppTypography.bodySmall.copyWith(
                              color: Colors.white.withOpacity(0.85),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    if (widget.isFromUpload)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange.shade700),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Bank details are required to upload content and receive donations.',
                                style: TextStyle(color: Colors.orange.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Account Number
                    PillTextFieldOutlined(
                      controller: _accountNumberController,
                      labelText: 'Account Number *',
                      hintText: 'Enter your bank account number',
                      prefixIcon: Icons.account_balance,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter account number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // IFSC Code
                    PillTextFieldOutlined(
                      controller: _ifscCodeController,
                      labelText: 'IFSC Code *',
                      hintText: 'e.g., HDFC0001234',
                      prefixIcon: Icons.qr_code,
                      textCapitalization: TextCapitalization.characters,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter IFSC code';
                        }
                        if (value.length != 11) {
                          return 'IFSC code must be 11 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // SWIFT Code (Optional)
                    PillTextFieldOutlined(
                      controller: _swiftCodeController,
                      labelText: 'SWIFT Code (Optional)',
                      hintText: 'For international transfers',
                      prefixIcon: Icons.code,
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 16),
                    
                    // Bank Name
                    PillTextFieldOutlined(
                      controller: _bankNameController,
                      labelText: 'Bank Name *',
                      hintText: 'e.g., HDFC Bank',
                      prefixIcon: Icons.account_balance_wallet,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter bank name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Account Holder Name
                    PillTextFieldOutlined(
                      controller: _accountHolderNameController,
                      labelText: 'Account Holder Name *',
                      hintText: 'Name as on bank account',
                      prefixIcon: Icons.person,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter account holder name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Branch Name
                    PillTextFieldOutlined(
                      controller: _branchNameController,
                      labelText: 'Branch Name *',
                      hintText: 'Bank branch name',
                      prefixIcon: Icons.location_on,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter branch name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    
                    // Save Button - Pill shaped
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.warmBrown,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.warmBrown.withOpacity(0.5),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _hasExistingDetails ? 'Update Bank Details' : 'Save Bank Details',
                                style: AppTypography.body.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    
                    const SizedBox(height: AppSpacing.extraLarge),
                  ],
                ),
              ),
            ),
    );
  }
}
