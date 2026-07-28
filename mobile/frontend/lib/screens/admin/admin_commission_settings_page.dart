import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/commission_settings.dart';
import '../../services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/admin/admin_stat_grid.dart';
import '../../widgets/admin/admin_page_scaffold.dart';
import '../../widgets/shared/pill_text_field.dart';

class AdminCommissionSettingsPage extends StatefulWidget {
  const AdminCommissionSettingsPage({super.key});

  @override
  State<AdminCommissionSettingsPage> createState() =>
      _AdminCommissionSettingsPageState();
}

class _AdminCommissionSettingsPageState
    extends State<AdminCommissionSettingsPage> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _percentageController = TextEditingController();
  final _fixedController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  bool _isActive = false;
  String _commissionType = 'percentage';
  DateTime? _updatedAt;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _percentageController.dispose();
    _fixedController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _api.getCommissionSettings();
      final settings = CommissionSettings.fromJson(data);
      if (!mounted) return;
      setState(() {
        _isActive = settings.isActive;
        _commissionType = settings.commissionType;
        _percentageController.text =
            settings.commissionPercentage.toStringAsFixed(1);
        _fixedController.text =
            settings.commissionFixedAmount.toStringAsFixed(2);
        _updatedAt = settings.updatedAt;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final data = await _api.updateCommissionSettings({
        'is_active': _isActive,
        'commission_type': _commissionType,
        'commission_percentage':
            double.tryParse(_percentageController.text) ?? 0,
        'commission_fixed_amount': double.tryParse(_fixedController.text) ?? 0,
      });
      final settings = CommissionSettings.fromJson(data);
      if (!mounted) return;
      setState(() {
        _updatedAt = settings.updatedAt;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Commission settings saved')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.errorMain,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: const Text('Commission Settings'),
        backgroundColor: AppColors.warmBrown,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.warmBrown),
            )
          : _error != null
              ? AdminErrorState(
                  title: 'Error loading settings',
                  message: _error!,
                  onRetry: _loadSettings,
                )
              : AdminPageScaffold(
                  padding: const EdgeInsets.all(16),
                  child: AdminContentMaxWidth(
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        children: [
                          SwitchListTile(
                            title: const Text('Commission active'),
                            subtitle: Text(
                              _isActive
                                  ? 'Platform commission is enabled'
                                  : 'Commission is disabled',
                            ),
                            value: _isActive,
                            activeColor: AppColors.warmBrown,
                            onChanged: (v) => setState(() => _isActive = v),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Commission type',
                            style: AppTypography.heading4.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...['percentage', 'fixed', 'percentage_plus_fixed']
                              .map(
                            (type) => RadioListTile<String>(
                              title: Text(_labelForType(type)),
                              value: type,
                              groupValue: _commissionType,
                              activeColor: AppColors.warmBrown,
                              onChanged: _isActive
                                  ? (v) => setState(() => _commissionType = v!)
                                  : null,
                            ),
                          ),
                          if (_commissionType.contains('percentage')) ...[
                            const SizedBox(height: 8),
                            PillTextFieldOutlined(
                              controller: _percentageController,
                              labelText: 'Percentage (%)',
                              hintText: 'e.g. 10',
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (!_isActive ||
                                    !_commissionType.contains('percentage')) {
                                  return null;
                                }
                                if (v == null || v.isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                            ),
                          ],
                          if (_commissionType.contains('fixed')) ...[
                            const SizedBox(height: 12),
                            PillTextFieldOutlined(
                              controller: _fixedController,
                              labelText: 'Fixed amount (GHS)',
                              hintText: 'e.g. 5.00',
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                if (!_isActive ||
                                    !_commissionType.contains('fixed')) {
                                  return null;
                                }
                                if (v == null || v.isEmpty) {
                                  return 'Required';
                                }
                                return null;
                              },
                            ),
                          ],
                          if (_updatedAt != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Last updated: ${DateFormat.yMMMd().add_jm().format(_updatedAt!.toLocal())}',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _isSaving ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.warmBrown,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Save settings'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  String _labelForType(String type) {
    switch (type) {
      case 'percentage':
        return 'Percentage only';
      case 'fixed':
        return 'Fixed amount only';
      case 'percentage_plus_fixed':
        return 'Percentage + fixed amount';
      default:
        return type;
    }
  }
}
