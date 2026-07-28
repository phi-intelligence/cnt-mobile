import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/donation.dart';
import '../../services/donation_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/admin/admin_filter_chips.dart';
import '../../widgets/admin/admin_page_scaffold.dart';
import '../../widgets/shared/empty_state.dart';

class AdminDonationsPage extends StatefulWidget {
  const AdminDonationsPage({super.key});

  @override
  State<AdminDonationsPage> createState() => _AdminDonationsPageState();
}

class _AdminDonationsPageState extends State<AdminDonationsPage> {
  final DonationService _donationService = DonationService();
  final List<DonationHistoryItem> _donations = [];

  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  int _total = 0;
  double? _totalAmount;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _loadDonations();
  }

  Future<void> _loadDonations({bool loadMore = false}) async {
    if (loadMore) {
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final page = await _donationService.listAllAdmin(
        offset: loadMore ? _donations.length : 0,
        statusFilter: _statusFilter,
      );

      if (!mounted) return;
      setState(() {
        if (loadMore) {
          _donations.addAll(page.donations);
        } else {
          _donations
            ..clear()
            ..addAll(page.donations);
        }
        _total = page.total;
        _totalAmount = page.totalAmount;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return DateFormat.yMMMd().add_jm().format(date.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: const Text('All Donations'),
        backgroundColor: AppColors.warmBrown,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.warmBrown),
            )
          : _error != null
              ? AdminErrorState(
                  title: 'Error loading donations',
                  message: _error!,
                  onRetry: () => _loadDonations(),
                )
              : AdminPageScaffold(
                  onRefresh: () => _loadDonations(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_totalAmount != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'Completed total: GHS ${_totalAmount!.toStringAsFixed(2)}',
                            style: AppTypography.heading4.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      AdminFilterChips(
                        options: const [
                          'All',
                          'completed',
                          'pending',
                          'failed',
                        ],
                        selected: _statusFilter ?? 'All',
                        onSelected: (value) {
                          setState(() {
                            _statusFilter = value == 'All' ? null : value;
                          });
                          _loadDonations();
                        },
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _donations.isEmpty
                            ? const EmptyState(
                                icon: Icons.volunteer_activism_outlined,
                                title: 'No donations',
                                message: 'No donations match this filter.',
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount:
                                    _donations.length + (_donations.length < _total ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index >= _donations.length) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Center(
                                        child: _isLoadingMore
                                            ? const CircularProgressIndicator(
                                                color: AppColors.warmBrown,
                                              )
                                            : TextButton(
                                                onPressed: () =>
                                                    _loadDonations(loadMore: true),
                                                child: const Text('Load more'),
                                              ),
                                      ),
                                    );
                                  }
                                  final item = _donations[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.formattedAmount,
                                                  style: AppTypography.heading4
                                                      .copyWith(
                                                    color: AppColors.textPrimary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                item.status,
                                                style: AppTypography.caption
                                                    .copyWith(
                                                  color: AppColors.textSecondary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Donor: ${item.donor?.name ?? 'Unknown'}',
                                            style: AppTypography.bodySmall,
                                          ),
                                          Text(
                                            'Recipient: ${item.recipient?.name ?? 'Unknown'}',
                                            style: AppTypography.bodySmall
                                                .copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          if (item.contentTitle != null &&
                                              item.contentTitle!.isNotEmpty)
                                            Text(
                                              'Content: ${item.contentTitle}',
                                              style: AppTypography.caption
                                                  .copyWith(
                                                color: AppColors.textTertiary,
                                              ),
                                            ),
                                          const SizedBox(height: 8),
                                          Text(
                                            _formatDate(item.createdAt),
                                            style: AppTypography.caption.copyWith(
                                              color: AppColors.textTertiary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
