import 'dart:async';

import 'package:flutter/material.dart';
import '../../models/api_models.dart';
import '../../models/document_asset.dart';
import '../../screens/bible/bible_document_selector_screen.dart';
import '../../screens/bible/bible_reader_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Bible Reader card carousel styled like a lightweight PDF viewer.
class BibleReaderSection extends StatefulWidget {
  final List<BibleStory> stories;
  final List<DocumentAsset> documents;
  final void Function(BibleStory)? onOpenStory;
  final void Function(DocumentAsset)? onOpenDocument;
  final bool isWeb;

  const BibleReaderSection({
    super.key,
    required this.stories,
    this.documents = const [],
    this.onOpenStory,
    this.onOpenDocument,
    this.isWeb = false,
  });

  @override
  State<BibleReaderSection> createState() => _BibleReaderSectionState();
}

class _BibleReaderSectionState extends State<BibleReaderSection> {
  final PageController _pageController = PageController(viewportFraction: 0.9);
  int _currentPage = 0;
  Timer? _autoPageTimer;

  @override
  void initState() {
    super.initState();
    _setupAutoPager();
  }

  @override
  void didUpdateWidget(covariant BibleReaderSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stories.length != widget.stories.length) {
      _setupAutoPager();
    }
  }

  void _setupAutoPager() {
    _autoPageTimer?.cancel();
    if (widget.stories.length <= 1) return;
    _autoPageTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!mounted) return;
      final next = (_currentPage + 1) % widget.stories.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoPageTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasDocuments = widget.documents.isNotEmpty;
    final itemCount =
        hasDocuments ? widget.documents.length : widget.stories.length;

    if (itemCount == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bible Reader',
          style: AppTypography.heading2.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.medium),
        SizedBox(
          // Give the card a bit more room on mobile to avoid overflow,
          // web keeps a slightly shorter, more compact height.
          height: widget.isWeb ? 180 : 220,
          child: PageView.builder(
            controller: _pageController,
            scrollDirection: widget.isWeb ? Axis.horizontal : Axis.vertical,
            physics: widget.isWeb
                ? const PageScrollPhysics()
                : const BouncingScrollPhysics(),
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemCount: itemCount,
            itemBuilder: (context, index) {
              final story = hasDocuments ? null : widget.stories[index];
              final document =
                  hasDocuments ? widget.documents[index] : null;
              return Padding(
                padding: EdgeInsets.only(
                  right: widget.isWeb ? AppSpacing.medium : 0,
                  bottom: widget.isWeb ? 0 : AppSpacing.medium,
                ),
                child: _BiblePageCard(
                  story: story,
                  document: document,
                  onOpenStory: widget.onOpenStory,
                  onOpenDocument: (doc) => _handleDocumentTap(doc),
                  isActive: index == _currentPage,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.small),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(itemCount, (index) {
            final isActive = index == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              width: isActive ? 28 : 12,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primaryMain
                    : AppColors.primaryMain.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
            );
          }),
        ),
      ],
    );
  }
  
  Future<void> _handleDocumentTap(DocumentAsset? doc) async {
    if (doc == null) return;

    DocumentAsset? selectedDoc = doc;

    // If multiple documents exist, allow the user to pick a version
    if (widget.documents.length > 1) {
      selectedDoc = await Navigator.push<DocumentAsset>(
        context,
        MaterialPageRoute(
          builder: (_) => BibleDocumentSelectorScreen(documents: widget.documents),
        ),
      );

      // User dismissed selector without choosing; fall back to original doc
      selectedDoc ??= doc;
    }

    final docToOpen = selectedDoc;
    if (docToOpen == null) return;

    if (widget.onOpenDocument != null) {
      widget.onOpenDocument!(docToOpen);
      return;
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BibleReaderScreen(document: docToOpen),
      ),
    );
  }
}

class _BiblePageCard extends StatefulWidget {
  final BibleStory? story;
  final DocumentAsset? document;
  final void Function(BibleStory)? onOpenStory;
  final void Function(DocumentAsset)? onOpenDocument;
  final bool isActive;

  const _BiblePageCard({
    required this.story,
    required this.document,
    required this.onOpenStory,
    required this.onOpenDocument,
    required this.isActive,
  });

  @override
  State<_BiblePageCard> createState() => _BiblePageCardState();
}

class _BiblePageCardState extends State<_BiblePageCard> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: widget.isActive ? 8 : 3,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
      color: AppColors.warmBrown.withOpacity(0.95),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.medium),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          color: AppColors.warmBrown.withOpacity(0.95),
          boxShadow: [
            BoxShadow(
              color: AppColors.warmBrown.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.document?.title ?? widget.story?.title ?? 'Bible Document',
              style: AppTypography.heading3.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textInverse,
              ),
            ),
            const SizedBox(height: AppSpacing.small),
            if (widget.document == null)
              Text(
                widget.story?.scriptureReference ?? '',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textInverse.withOpacity(0.9),
                ),
              )
            else
              Text(
                widget.document!.category ?? 'Bible Document',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textInverse.withOpacity(0.9),
                ),
              ),
            const SizedBox(height: AppSpacing.medium),
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                interactive: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: EdgeInsets.zero,
                  child: Text(
                    widget.document?.description ?? widget.story?.content ?? '',
                    style: AppTypography.bodyMedium.copyWith(
                      height: 1.5,
                      color: AppColors.textInverse.withOpacity(0.85),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.medium),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: widget.document != null
                    ? (widget.onOpenDocument != null
                        ? () => widget.onOpenDocument?.call(widget.document!)
                        : null)
                    : (widget.story != null && widget.onOpenStory != null)
                        ? () => widget.onOpenStory?.call(widget.story!)
                        : null,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textInverse,
                  backgroundColor: Colors.white.withOpacity(0.2),
                ),
                icon: Icon(
                  widget.document != null
                      ? Icons.picture_as_pdf_outlined
                      : Icons.menu_book_outlined,
                  color: AppColors.textInverse,
                ),
                label: Text(
                  widget.document != null
                      ? 'Open PDF'
                      : 'Open Full Chapter',
                  style: const TextStyle(
                    color: AppColors.textInverse,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


