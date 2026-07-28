import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/donation.dart';
import '../../services/donation_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class DonationHistoryScreenMobile extends StatefulWidget {
  const DonationHistoryScreenMobile({super.key});

  @override
  State<DonationHistoryScreenMobile> createState() =>
      _DonationHistoryScreenMobileState();
}

class _DonationHistoryScreenMobileState
    extends State<DonationHistoryScreenMobile>
    with SingleTickerProviderStateMixin {
  final DonationService _donationService = DonationService();
  late final TabController _tabController;

  final List<DonationHistoryItem> _received = [];
  final List<DonationHistoryItem> _sent = [];
  bool _loadingReceived = true;
  bool _loadingSent = true;
  String? _receivedError;
  String? _sentError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadReceived();
    _loadSent();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadReceived() async {
    setState(() {
      _loadingReceived = true;
      _receivedError = null;
    });
    try {
      final page = await _donationService.listReceived();
      if (!mounted) return;
      setState(() {
        _received
          ..clear()
          ..addAll(page.donations);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _receivedError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingReceived = false);
    }
  }

  Future<void> _loadSent() async {
    setState(() {
      _loadingSent = true;
      _sentError = null;
    });
    try {
      final page = await _donationService.listSent();
      if (!mounted) return;
      setState(() {
        _sent
          ..clear()
          ..addAll(page.donations);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _sentError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingSent = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        title: const Text('Donation History'),
        backgroundColor: AppColors.backgroundPrimary,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.warmBrown,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.warmBrown,
          tabs: const [
            Tab(text: 'Received'),
            Tab(text: 'Sent'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(
            loading: _loadingReceived,
            error: _receivedError,
            items: _received,
            emptyLabel: 'No donations received yet',
            onRefresh: _loadReceived,
            counterpart: (item) => item.donor?.name ?? 'Donor',
          ),
          _buildList(
            loading: _loadingSent,
            error: _sentError,
            items: _sent,
            emptyLabel: 'No donations sent yet',
            onRefresh: _loadSent,
            counterpart: (item) => item.recipient?.name ?? 'Recipient',
          ),
        ],
      ),
    );
  }

  Widget _buildList({
    required bool loading,
    required String? error,
    required List<DonationHistoryItem> items,
    required String emptyLabel,
    required Future<void> Function() onRefresh,
    required String Function(DonationHistoryItem) counterpart,
  }) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.warmBrown),
      );
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(onPressed: onRefresh, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (items.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    final dateFmt = DateFormat.yMMMd().add_jm();
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.warmBrown,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.large),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppColors.borderPrimary),
            ),
            title: Text(
              item.formattedAmount,
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${counterpart(item)}\n'
              '${item.status}'
              '${item.createdAt != null ? ' · ${dateFmt.format(item.createdAt!.toLocal())}' : ''}',
            ),
            isThreeLine: true,
          );
        },
      ),
    );
  }
}
