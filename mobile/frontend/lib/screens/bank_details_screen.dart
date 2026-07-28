import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/creator_payout.dart';
import '../providers/auth_provider.dart';
import '../providers/creator_provider.dart';
import '../screens/artist/artist_profile_manage_screen.dart';
import '../services/creator_payout_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/app_logger.dart';

/// Paystack creator payout settings (bank / MoMo subaccount onboarding).
class BankDetailsScreen extends StatefulWidget {
  final bool isFromUpload;
  final bool isFromCreator;

  const BankDetailsScreen({
    super.key,
    this.isFromUpload = false,
    this.isFromCreator = false,
  });

  @override
  State<BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends State<BankDetailsScreen> {
  final CreatorPayoutService _payoutService = CreatorPayoutService();
  final _formKey = GlobalKey<FormState>();

  final _accountNumberController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();

  CreatorPayoutStatus? _status;
  List<CreatorPayoutBank> _banks = [];
  String _settlementType = 'bank';
  int? _selectedBankId;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _showEditForm = false;
  String? _error;

  bool get _isConfigured =>
      _status?.acceptsDonations == true && _status?.payoutsEnabled == true;

  bool get _isMobileMoney => _settlementType == 'mobile_money';

  List<CreatorPayoutBank> get _providersForSettlementType {
    if (_isMobileMoney) {
      return _banks
          .where((b) => (b.type ?? '').toLowerCase() == 'mobile_money')
          .toList();
    }
    return _banks
        .where((b) => (b.type ?? '').toLowerCase() != 'mobile_money')
        .toList();
  }

  CreatorPayoutBank? get _selectedProvider {
    if (_selectedBankId == null) return null;
    for (final bank in _banks) {
      if (bank.id == _selectedBankId) return bank;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _prefillContactFields();
    });
    _loadData();
  }

  void _prefillContactFields() {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    final name = (user['full_name'] ?? user['username'] ?? '').toString();
    final email = (user['email'] ?? '').toString();
    if (_contactNameController.text.isEmpty && name.isNotEmpty) {
      _contactNameController.text = name;
    }
    if (_contactEmailController.text.isEmpty && email.isNotEmpty) {
      _contactEmailController.text = email;
    }
    if (_businessNameController.text.isEmpty && name.isNotEmpty) {
      _businessNameController.text = name;
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _payoutService.getMe(),
        _payoutService.listBanks(),
      ]);
      if (!mounted) return;
      setState(() {
        _status = results[0] as CreatorPayoutStatus;
        _banks = results[1] as List<CreatorPayoutBank>;
        _showEditForm = !(_status?.isConfigured ?? false);
        if (_status?.settlementType != null) {
          _settlementType = _status!.settlementType!;
        }
      });
    } catch (e) {
      AppLogger.error('Error loading payout settings', error: e);
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSettlementTypeChanged(String nextType) {
    setState(() {
      _settlementType = nextType;
      _selectedBankId = null;
    });
  }

  Future<void> _submit({required bool isUpdate}) async {
    if (!_formKey.currentState!.validate()) return;

    final selected = _selectedProvider;
    if (selected == null || selected.code.isEmpty) {
      _showSnackBar('Please select a bank or mobile money provider.',
          isError: true);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final payload = CreatorPayoutOnboardRequest(
      settlementType: _settlementType,
      settlementBankCode: selected.code,
      accountNumber: _accountNumberController.text.trim(),
      businessName: _businessNameController.text.trim(),
      primaryContactName: _contactNameController.text.trim(),
      primaryContactEmail: _contactEmailController.text.trim().isEmpty
          ? null
          : _contactEmailController.text.trim(),
      primaryContactPhone: _contactPhoneController.text.trim().isEmpty
          ? null
          : _contactPhoneController.text.trim(),
    );

    try {
      final status = isUpdate
          ? await _payoutService.update(payload)
          : await _payoutService.onboard(payload);

      if (!mounted) return;

      setState(() {
        _status = status;
        _showEditForm = false;
        _accountNumberController.clear();
      });

      await context.read<CreatorProvider>().refresh();
      if (!mounted) return;

      if (widget.isFromCreator &&
          status.acceptsDonations &&
          status.payoutsEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "You're a creator — you can now publish content.",
            ),
            backgroundColor: AppColors.successMain,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const ArtistProfileManageScreen(),
          ),
        );
        return;
      }

      _showSnackBar(
        isUpdate
            ? 'Payout settings updated successfully.'
            : 'Payout setup complete — you can now receive donations.',
      );

      if (widget.isFromUpload && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      AppLogger.error('Error saving payout settings', error: e);
      if (mounted) {
        setState(() => _error = e.toString());
        _showSnackBar(e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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

  String? _validateAccountNumber(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return _isMobileMoney
          ? 'Enter your mobile money number'
          : 'Enter your bank account number';
    }
    final digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');
    if (_isMobileMoney) {
      if (digitsOnly.length < 9 || digitsOnly.length > 13) {
        return 'Enter a valid Ghana mobile money number';
      }
    } else if (digitsOnly.length < 8) {
      return 'Enter a valid bank account number';
    }
    return null;
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    _businessNameController.dispose();
    _contactNameController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: Text(widget.isFromCreator ? 'Become a Creator' : 'Payout Settings'),
        backgroundColor: AppColors.backgroundPrimary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.warmBrown),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.warmBrown,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.large),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.isFromCreator)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.large),
                        child: Text(
                          'Set up Paystack payouts so you can publish content and receive donations.',
                          style: AppTypography.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.medium),
                        child: Text(
                          _error!,
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.errorMain),
                        ),
                      ),
                    if (_isConfigured && !_showEditForm) ...[
                      _buildStatusCard(),
                      const SizedBox(height: AppSpacing.large),
                      OutlinedButton(
                        onPressed: () => setState(() => _showEditForm = true),
                        child: const Text('Edit payout settings'),
                      ),
                    ] else
                      _buildForm(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    final status = _status!;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.large),
      decoration: BoxDecoration(
        color: AppColors.successMain.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.successMain.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.successMain),
              const SizedBox(width: 8),
              Text(
                'Donations Enabled',
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.successMain,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.medium),
          if (status.businessName != null)
            Text('Business: ${status.businessName}'),
          if (status.settlementType != null)
            Text('Type: ${status.settlementType}'),
          if (status.accountNumberLast4 != null)
            Text('Account ending: •••• ${status.accountNumberLast4}'),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final providers = _providersForSettlementType;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Settlement type', style: AppTypography.bodySmall),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'bank', label: Text('Bank')),
              ButtonSegment(value: 'mobile_money', label: Text('MoMo')),
            ],
            selected: {_settlementType},
            onSelectionChanged: (s) => _onSettlementTypeChanged(s.first),
          ),
          const SizedBox(height: AppSpacing.large),
          DropdownButtonFormField<int>(
            value: _selectedBankId,
            decoration: InputDecoration(
              labelText: _isMobileMoney ? 'Mobile money provider' : 'Bank',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: providers
                .map(
                  (b) => DropdownMenuItem(
                    value: b.id,
                    child: Text(b.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _selectedBankId = v),
            validator: (v) => v == null ? 'Select a provider' : null,
          ),
          const SizedBox(height: AppSpacing.medium),
          TextFormField(
            controller: _accountNumberController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _isMobileMoney ? 'Mobile money number' : 'Account number',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: _validateAccountNumber,
          ),
          const SizedBox(height: AppSpacing.medium),
          TextFormField(
            controller: _businessNameController,
            decoration: InputDecoration(
              labelText: 'Business / display name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: AppSpacing.medium),
          TextFormField(
            controller: _contactNameController,
            decoration: InputDecoration(
              labelText: 'Contact name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: AppSpacing.medium),
          TextFormField(
            controller: _contactEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Contact email (optional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          TextFormField(
            controller: _contactPhoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Contact phone (optional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: AppSpacing.extraLarge),
          ElevatedButton(
            onPressed: _isSubmitting
                ? null
                : () => _submit(isUpdate: _isConfigured),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warmBrown,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(_isConfigured ? 'Update payouts' : 'Set up payouts'),
          ),
          if (_isConfigured) ...[
            const SizedBox(height: AppSpacing.medium),
            TextButton(
              onPressed: () => setState(() => _showEditForm = false),
              child: const Text('Cancel'),
            ),
          ],
        ],
      ),
    );
  }
}
