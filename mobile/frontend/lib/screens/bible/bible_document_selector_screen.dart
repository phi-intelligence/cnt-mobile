import 'package:flutter/material.dart';

import '../../models/document_asset.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class BibleDocumentSelectorScreen extends StatelessWidget {
  final List<DocumentAsset> documents;

  const BibleDocumentSelectorScreen({
    super.key,
    required this.documents,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        title: Text(
          'Select Bible Version',
          style: AppTypography.heading4.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView.separated(
        padding: EdgeInsets.all(AppSpacing.medium),
        itemCount: documents.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.small),
        itemBuilder: (context, index) {
          final doc = documents[index];
          return ListTile(
            tileColor: AppColors.backgroundSecondary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
            ),
            title: Text(
              doc.title ?? 'Bible Document',
              style: AppTypography.heading4.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: doc.description != null
                ? Text(
                    doc.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  )
                : null,
            trailing: Icon(Icons.menu_book_outlined, color: AppColors.primaryMain),
            onTap: () => Navigator.pop(context, doc),
          );
        },
      ),
    );
  }
}

