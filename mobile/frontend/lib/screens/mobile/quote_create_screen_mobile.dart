import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/community_provider.dart';
import '../../providers/creator_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Mobile Quote Creation Screen - Simple text input for creating quotes
/// Backend automatically generates image with predefined templates
class QuoteCreateScreenMobile extends StatefulWidget {
  const QuoteCreateScreenMobile({super.key});

  @override
  State<QuoteCreateScreenMobile> createState() => _QuoteCreateScreenMobileState();
}

class _QuoteCreateScreenMobileState extends State<QuoteCreateScreenMobile> {
  final _formKey = GlobalKey<FormState>();
  final _quoteController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<CreatorProvider>().ensureReadyOrRedirect(context);
    });
  }

  @override
  void dispose() {
    _quoteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final quoteText = _quoteController.text.trim();
    if (quoteText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a quote'),
          backgroundColor: AppColors.errorMain,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final communityProvider = Provider.of<CommunityProvider>(context, listen: false);
      
      await communityProvider.createPost(
        title: quoteText.split('\n').first,  // Use first line as title
        content: quoteText,
        category: 'General',
        postType: 'text',  // Backend will auto-generate image
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quote submitted! It will be reviewed by an admin.'),
          backgroundColor: AppColors.successMain,
          duration: Duration(seconds: 3),
        ),
      );

      // Navigate back
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to create quote: $e'),
          backgroundColor: AppColors.errorMain,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Create Quote',
          style: AppTypography.heading3.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppSpacing.large),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header icon and description
                Container(
                  padding: EdgeInsets.all(AppSpacing.large),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.warmBrown.withOpacity(0.1),
                        AppColors.accentMain.withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.format_quote,
                        size: 48,
                        color: AppColors.warmBrown,
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      Text(
                        'Share an Inspiring Quote',
                        style: AppTypography.heading3.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.small),
                      Text(
                        'The system will automatically create a beautiful image for your quote.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.extraLarge),

                // Quote input
                TextFormField(
                  controller: _quoteController,
                  maxLines: null,
                  minLines: 6,
                  expands: false,
                  textAlignVertical: TextAlignVertical.top,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter your inspirational quote or Bible verse...',
                    hintStyle: AppTypography.body.copyWith(
                      color: AppColors.textTertiary,
                      fontSize: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                      borderSide: BorderSide(color: AppColors.borderPrimary),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                      borderSide: BorderSide(color: AppColors.borderPrimary),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                      borderSide: BorderSide(color: AppColors.warmBrown, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                      borderSide: BorderSide(color: AppColors.errorMain),
                    ),
                    filled: true,
                    fillColor: AppColors.backgroundSecondary,
                    contentPadding: EdgeInsets.all(AppSpacing.medium),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a quote';
                    }
                    if (value.trim().length < 10) {
                      return 'Quote must be at least 10 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.large),

                // Info message
                Container(
                  padding: EdgeInsets.all(AppSpacing.medium),
                  decoration: BoxDecoration(
                    color: AppColors.warmBrown.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                    border: Border.all(
                      color: AppColors.warmBrown.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.warmBrown,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.small),
                      Expanded(
                        child: Text(
                          'Your quote will be automatically styled and converted to an image. It will be reviewed by an admin before appearing in the community.',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.warmBrown,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.extraLarge),

                // Submit button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warmBrown,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                      ),
                      elevation: 2,
                      disabledBackgroundColor: AppColors.warmBrown.withOpacity(0.5),
                    ),
                    child: _isSubmitting
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.format_quote, size: 24),
                              const SizedBox(width: AppSpacing.small),
                              Text(
                                'Create Quote',
                                style: AppTypography.button.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

