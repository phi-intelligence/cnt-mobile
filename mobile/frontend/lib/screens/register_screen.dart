import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../navigation/mobile_navigation.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../widgets/shared/pill_text_field.dart';
import '../utils/security_hardening.dart';
import 'user_login_screen.dart';

/// Register Screen - Redesigned to match Web Register Screen style
/// Features warm cream background, pill-shaped inputs, and Google sign-up
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _obscurePassword = true;
  DateTime? _selectedDateOfBirth;
  String? _generatedUsername;
  bool _isGoogleLoading = false;
  bool _showOptionalFields = false;

  // OTP Flow State
  bool _isOTPSent = false;
  bool _isOTPVerified = false;
  final _otpController = TextEditingController();
  bool _isSendingOTP = false;
  bool _isVerifyingOTP = false;
  Timer? _resendTimer;
  int _resendCountdown = 0;
  String? _otpError;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _generateUsernamePreview() {
    // Clear username if both fields are empty
    if (_emailController.text.isEmpty && _nameController.text.isEmpty) {
      setState(() {
        _generatedUsername = null;
      });
      return;
    }

    // Prioritize email for username generation
    if (_emailController.text.isNotEmpty) {
      final email = _emailController.text.trim();
      if (email.contains('@')) {
        final username = email.split('@')[0].toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '');
        setState(() {
          _generatedUsername = username;
        });
      }
    } else if (_nameController.text.isNotEmpty) {
      final name = _nameController.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '').replaceAll(' ', '');
      setState(() {
        _generatedUsername = name;
      });
    }
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.warmBrown,
              onPrimary: Colors.white,
              surface: const Color(0xFFF5F0E8),
              onSurface: AppColors.primaryDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDateOfBirth) {
      setState(() {
        _selectedDateOfBirth = picked;
      });
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // If OTP not sent yet, send OTP first
    if (!_isOTPSent) {
      await _sendOTP();
      return;
    }

    // If OTP sent but not verified, verify OTP first
    if (_isOTPSent && !_isOTPVerified) {
      await _verifyOTP();
      return;
    }

    // If OTP verified, proceed with registration
    if (_isOTPVerified) {
      await _completeRegistration();
    }
  }

  Future<void> _sendOTP() async {
    setState(() {
      _isSendingOTP = true;
      _otpError = null;
    });

    try {
      final authService = AuthService();
      await authService.sendOTP(_emailController.text.trim());

      setState(() {
        _isOTPSent = true;
        _isSendingOTP = false;
        _resendCountdown = 60; // 60 seconds countdown
      });

      // Start resend countdown timer
      _resendTimer?.cancel();
      _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            if (_resendCountdown > 0) {
              _resendCountdown--;
            } else {
              timer.cancel();
            }
          });
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification code sent to ${_emailController.text.trim()}'),
            backgroundColor: AppColors.successMain,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSendingOTP = false;
        _otpError = e.toString().replaceAll('Exception: ', '');
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_otpError!),
            backgroundColor: AppColors.errorMain,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _verifyOTP() async {
    if (_otpController.text.trim().length != 6) {
      setState(() {
        _otpError = 'Please enter a 6-digit verification code';
      });
      return;
    }

    setState(() {
      _isVerifyingOTP = true;
      _otpError = null;
    });

    try {
      final authService = AuthService();
      final result = await authService.verifyOTP(
        _emailController.text.trim(),
        _otpController.text.trim(),
      );

      if (result['verified'] == true) {
        setState(() {
          _isOTPVerified = true;
          _isVerifyingOTP = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email verified successfully'),
              backgroundColor: AppColors.successMain,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }

        // Automatically proceed to registration
        await _completeRegistration();
      } else {
        setState(() {
          _isVerifyingOTP = false;
          _otpError = result['message'] ?? 'Invalid verification code';
        });
      }
    } catch (e) {
      setState(() {
        _isVerifyingOTP = false;
        _otpError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _completeRegistration() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.registerWithOTP(
      email: _emailController.text.trim(),
      otpCode: _otpController.text.trim(),
      password: _passwordController.text,
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      dateOfBirth: _selectedDateOfBirth,
    );

    if (mounted) {
      if (success) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const MobileNavigationLayout(),
          ),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.error ?? 'Registration failed'),
            backgroundColor: AppColors.errorMain,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _resendOTP() async {
    if (_resendCountdown > 0) return;
    await _sendOTP();
  }

  Future<void> _handleGoogleSignUp() async {
    setState(() => _isGoogleLoading = true);
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.googleLogin();

    if (mounted) {
      setState(() => _isGoogleLoading = false);
      
      if (success) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const MobileNavigationLayout(),
          ),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.error ?? 'Google sign-up failed'),
            backgroundColor: AppColors.errorMain,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SecureScreen(
      child: Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppColors.primaryDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/CNT-LOGO.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(Icons.church, color: AppColors.warmBrown);
                  },
                ),
              ),
            ),
            SizedBox(width: AppSpacing.small),
            Text(
              'Christ New Tabernacle',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.extraLarge,
            vertical: AppSpacing.medium,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title
                Text(
                  'Create Account',
                  style: AppTypography.heading1.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 8),
                
                // Subtitle
                Text(
                  'Join Christ New Tabernacle\nand start your spiritual journey',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.primaryDark.withOpacity(0.6),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                SizedBox(height: AppSpacing.extraLarge),
                
                // Google Sign Up Button
                _buildGoogleButton(),
                
                SizedBox(height: AppSpacing.large),
                
                // Divider with "or"
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: AppColors.warmBrown.withOpacity(0.3),
                        thickness: 1,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.medium),
                      child: Text(
                        'or continue with email',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primaryDark.withOpacity(0.5),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: AppColors.warmBrown.withOpacity(0.3),
                        thickness: 1,
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: AppSpacing.large),
                
                // Name Field - Using shared PillTextField
                PillTextField(
                  controller: _nameController,
                  hintText: 'Full Name',
                  prefixIcon: Icons.person_outline,
                  onChanged: (_) => _generateUsernamePreview(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                
                SizedBox(height: AppSpacing.medium),
                
                // Email Field - Using shared PillTextField
                PillTextField(
                  controller: _emailController,
                  hintText: 'Email address',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => _generateUsernamePreview(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),

                // OTP Section - Show after email is entered and validated
                if (_isOTPSent) ...[
                  SizedBox(height: AppSpacing.medium),

                  // OTP Info Card
                  Container(
                    padding: EdgeInsets.all(AppSpacing.medium),
                    decoration: BoxDecoration(
                      color: AppColors.warmBrown.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.warmBrown.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.mark_email_read_outlined,
                          color: AppColors.warmBrown,
                          size: 24,
                        ),
                        SizedBox(width: AppSpacing.small),
                        Expanded(
                          child: Text(
                            'We sent a 6-digit verification code to ${_emailController.text.trim()}',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primaryDark.withOpacity(0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: AppSpacing.medium),

                  // OTP Input Field
                  PillTextField(
                    controller: _otpController,
                    hintText: 'Enter 6-digit code',
                    prefixIcon: Icons.pin_outlined,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    enabled: !_isOTPVerified,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter verification code';
                      }
                      if (value.length != 6) {
                        return 'Code must be 6 digits';
                      }
                      return null;
                    },
                  ),

                  // OTP Error Message
                  if (_otpError != null) ...[
                    SizedBox(height: AppSpacing.small),
                    Text(
                      _otpError!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.errorMain,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  // Resend OTP Button
                  SizedBox(height: AppSpacing.small),
                  TextButton(
                    onPressed: _resendCountdown > 0 ? null : _resendOTP,
                    child: Text(
                      _resendCountdown > 0
                          ? 'Resend code in $_resendCountdown seconds'
                          : 'Resend verification code',
                      style: AppTypography.caption.copyWith(
                        color: _resendCountdown > 0
                            ? AppColors.primaryDark.withOpacity(0.4)
                            : AppColors.warmBrown,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],

                if (_isOTPSent)
                  SizedBox(height: AppSpacing.medium),

                // Password Field - Using shared PillTextField
                if (!_isOTPSent)
                  PillTextField(
                  controller: _passwordController,
                  hintText: 'Password',
                  prefixIcon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.warmBrown.withOpacity(0.6),
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),
                
                // Username preview
                if (_generatedUsername != null) ...[
                  SizedBox(height: AppSpacing.medium),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.large,
                      vertical: AppSpacing.small + 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warmBrown.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.warmBrown.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.alternate_email,
                          color: AppColors.warmBrown,
                          size: 16,
                        ),
                        SizedBox(width: AppSpacing.small),
                        Text(
                          'Username: $_generatedUsername',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.warmBrown,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                SizedBox(height: AppSpacing.medium),
                
                // Optional Fields Toggle
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showOptionalFields = !_showOptionalFields;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.medium,
                      vertical: AppSpacing.small,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _showOptionalFields ? Icons.expand_less : Icons.expand_more,
                          color: AppColors.warmBrown.withOpacity(0.6),
                        ),
                        SizedBox(width: AppSpacing.small),
                        Text(
                          'Additional Information (Optional)',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.primaryDark.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Optional Fields
                if (_showOptionalFields) ...[
                  SizedBox(height: AppSpacing.small),
                  
                  // Phone Field - Using shared PillTextField
                  PillTextField(
                    controller: _phoneController,
                    hintText: 'Phone (optional)',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  
                  SizedBox(height: AppSpacing.medium),
                  
                  // Date of Birth
                  _buildPillDatePicker(),
                ],
                
                SizedBox(height: AppSpacing.extraLarge),
                
                // Create Account Button
                Consumer<AuthProvider>(
                  builder: (context, authProvider, _) {
                    // Determine button label based on OTP state
                    String buttonLabel;
                    if (!_isOTPSent) {
                      buttonLabel = 'Send Verification Code';
                    } else if (_isOTPSent && !_isOTPVerified) {
                      buttonLabel = 'Verify Code';
                    } else {
                      buttonLabel = 'Create Account';
                    }

                    bool isButtonLoading = authProvider.isLoading || _isSendingOTP || _isVerifyingOTP;

                    return _buildPillButton(
                      label: buttonLabel,
                      onPressed: isButtonLoading ? null : _handleRegister,
                      isLoading: isButtonLoading,
                    );
                  },
                ),
                
                SizedBox(height: AppSpacing.large),
                
                // Login link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.primaryDark.withOpacity(0.6),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const UserLoginScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Sign In',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.warmBrown,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: AppSpacing.extraLarge),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  /// Pill-shaped date picker
  Widget _buildPillDatePicker() {
    return GestureDetector(
      onTap: _selectDateOfBirth,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: AppColors.warmBrown.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.large,
          vertical: AppSpacing.medium + 4,
        ),
        child: Row(
          children: [
            Padding(
              padding: EdgeInsets.only(right: AppSpacing.small),
              child: Icon(
                Icons.calendar_today_outlined,
                color: AppColors.warmBrown.withOpacity(0.7),
                size: 20,
              ),
            ),
            Expanded(
              child: Text(
                _selectedDateOfBirth == null
                    ? 'Date of Birth (optional)'
                    : DateFormat('MMMM d, yyyy').format(_selectedDateOfBirth!),
                style: AppTypography.body.copyWith(
                  color: _selectedDateOfBirth == null
                      ? AppColors.primaryDark.withOpacity(0.4)
                      : AppColors.primaryDark,
                  fontSize: 15,
                ),
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: AppColors.warmBrown.withOpacity(0.6),
            ),
          ],
        ),
      ),
    );
  }

  /// Pill-shaped button matching web design
  Widget _buildPillButton({
    required String label,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.warmBrown,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: AppColors.warmBrown.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(27),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.extraLarge + 8,
            vertical: AppSpacing.medium,
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: AppTypography.button.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  letterSpacing: 0.3,
                ),
              ),
      ),
    );
  }

  /// Google Sign Up button - pill shaped
  Widget _buildGoogleButton() {
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: _isGoogleLoading ? null : _handleGoogleSignUp,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primaryDark,
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          side: BorderSide(
            color: AppColors.warmBrown.withOpacity(0.3),
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(27),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.extraLarge,
            vertical: AppSpacing.medium,
          ),
        ),
        child: _isGoogleLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.warmBrown),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google "G" logo colors
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        'G',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          foreground: Paint()
                            ..shader = const LinearGradient(
                              colors: [
                                Color(0xFF4285F4),
                                Color(0xFF34A853),
                                Color(0xFFFBBC05),
                                Color(0xFFEA4335),
                              ],
                              stops: [0.0, 0.33, 0.66, 1.0],
                            ).createShader(const Rect.fromLTWH(0, 0, 22, 22)),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.medium),
                  Text(
                    'Sign up with Google',
                    style: AppTypography.button.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
