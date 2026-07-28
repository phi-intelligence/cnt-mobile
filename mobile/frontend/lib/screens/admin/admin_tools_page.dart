import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/admin/admin_page_scaffold.dart';
import '../../widgets/admin/admin_section_header.dart';
import 'admin_support_page.dart';
import 'admin_documents_page.dart';
import 'admin_commission_settings_page.dart';
import 'admin_donations_page.dart';
import 'bulk_upload_screen.dart';
import 'google_drive_picker_screen.dart';

/// Admin Tools Page - Hub for admin utilities.
class AdminToolsPage extends StatelessWidget {
  const AdminToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AdminSectionHeader(
              title: 'Admin Tools',
              subtitle: 'Manage content, documents, payments, and support',
            ),
            const SizedBox(height: 16),
            _buildSectionHeader('Content Management', Icons.content_paste),
            const SizedBox(height: 12),
            _buildToolCard(
              context: context,
              icon: Icons.cloud_upload,
              title: 'Bulk Upload',
              description: 'Upload multiple files at once',
              color: const Color(0xFF6366F1),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BulkUploadScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _buildToolCard(
              context: context,
              icon: Icons.menu_book,
              title: 'Bible Documents',
              description: 'Manage Bible and religious documents',
              color: AppColors.warmBrown,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminDocumentsPage()),
              ),
            ),
            const SizedBox(height: 12),
            _buildToolCard(
              context: context,
              icon: Icons.drive_folder_upload,
              title: 'Google Drive Import',
              description: 'Import media from Google Drive',
              color: const Color(0xFF4285F4),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const GoogleDrivePickerScreen(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('Payments', Icons.payments_outlined),
            const SizedBox(height: 12),
            _buildToolCard(
              context: context,
              icon: Icons.percent,
              title: 'Commission Settings',
              description: 'Configure platform donation commission',
              color: const Color(0xFF8B5CF6),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminCommissionSettingsPage(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildToolCard(
              context: context,
              icon: Icons.volunteer_activism,
              title: 'All Donations',
              description: 'View all platform donations',
              color: const Color(0xFFEC4899),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminDonationsPage()),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('Support', Icons.support_agent),
            const SizedBox(height: 12),
            _buildToolCard(
              context: context,
              icon: Icons.support_agent,
              title: 'Support Tickets',
              description: 'View and respond to user inquiries',
              color: const Color(0xFF10B981),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminSupportPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.warmBrown),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildToolCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
