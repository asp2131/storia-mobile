import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  int _step = 1;
  String _email = '';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _otpController.addListener(_onOtpChanged);
  }

  @override
  void dispose() {
    _otpController.removeListener(_onOtpChanged);
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _onOtpChanged() {
    if (_otpController.text.length == 6) {
      _handleVerifyOtp();
    }
  }

  Future<void> _handleSendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email address.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authStateProvider.notifier).sendOtp(email);
      setState(() {
        _email = email;
        _step = 2;
      });
    } catch (e) {
      setState(() => _errorMessage = 'Failed to send code. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleVerifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authStateProvider.notifier).verifyOtp(_email, otp);
    } catch (e) {
      _otpController.clear();
      setState(() => _errorMessage = 'Invalid code. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResendCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authStateProvider.notifier).sendOtp(_email);
      if (mounted) {
        setState(() => _errorMessage = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code resent.')),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to resend code.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goBackToEmail() {
    _otpController.clear();
    setState(() {
      _step = 1;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor =
        isDark ? theme.colorScheme.surface : const Color(0xFFF5F4EF);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: isDark
                    ? null
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFDCEBFF),
                          Color(0xFFEDE4FF),
                          Color(0xFFFFF5DD),
                        ],
                      ),
                color: isDark ? theme.colorScheme.surfaceContainerHigh : null,
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(68, 59, 130, 0.14),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'Storia',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 38,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? theme.colorScheme.onSurface
                            : const Color(0xFF41315D),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Stories that spark imagination',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? theme.colorScheme.onSurfaceVariant
                            : const Color(0xFF51456E),
                      ),
                    ),
                    const SizedBox(height: 32),
                    AnimatedSwitcher(
                      duration: 300.ms,
                      child: _step == 1
                          ? _buildStep1(isDark, theme)
                          : _buildStep2(isDark, theme),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 500.ms).slideY(
                  begin: 0.05,
                  end: 0,
                  duration: 500.ms,
                  curve: Curves.easeOutCubic,
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1(bool isDark, ThemeData theme) {
    return Column(
      key: const ValueKey('step1'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildEmailField(isDark, theme),
        if (_errorMessage != null) ...[
          const SizedBox(height: 14),
          _buildErrorBox(),
        ],
        const SizedBox(height: 20),
        _buildButton(
          label: 'Send Code',
          onPressed: _isLoading ? null : _handleSendOtp,
          isDark: isDark,
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildStep2(bool isDark, ThemeData theme) {
    final subtextColor = isDark
        ? theme.colorScheme.onSurfaceVariant
        : const Color(0xFF51456E);

    return Column(
      key: const ValueKey('step2'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Enter the 6-digit code sent to',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: subtextColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _email,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark
                ? theme.colorScheme.onSurface
                : const Color(0xFF41315D),
          ),
        ),
        const SizedBox(height: 20),
        _buildOtpField(isDark, theme),
        if (_errorMessage != null) ...[
          const SizedBox(height: 14),
          _buildErrorBox(),
        ],
        const SizedBox(height: 20),
        if (_isLoading)
          SizedBox(
            height: 50,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: isDark
                      ? theme.colorScheme.primary
                      : const Color(0xFF41315D),
                ),
              ),
            ),
          )
        else ...[
          TextButton(
            onPressed: _handleResendCode,
            child: Text(
              'Resend code',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: subtextColor,
              ),
            ),
          ),
          TextButton(
            onPressed: _goBackToEmail,
            child: Text(
              'Use a different email',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: subtextColor,
              ),
            ),
          ),
        ],
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildEmailField(bool isDark, ThemeData theme) {
    final fieldBg =
        isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white;
    final borderColor = isDark
        ? theme.colorScheme.outline.withValues(alpha: 0.35)
        : const Color(0xFFDCCFF3);
    final textColor =
        isDark ? theme.colorScheme.onSurface : const Color(0xFF2F2C42);
    final hintColor =
        isDark ? theme.colorScheme.onSurfaceVariant : const Color(0xFF9A91B0);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: TextField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _handleSendOtp(),
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Email address',
          hintStyle: GoogleFonts.inter(fontSize: 14, color: hintColor),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          prefixIcon: Icon(
            Icons.email_outlined,
            size: 20,
            color: hintColor,
          ),
        ),
      ),
    );
  }

  Widget _buildOtpField(bool isDark, ThemeData theme) {
    final fieldBg =
        isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white;
    final borderColor = isDark
        ? theme.colorScheme.outline.withValues(alpha: 0.35)
        : const Color(0xFFDCCFF3);
    final textColor =
        isDark ? theme.colorScheme.onSurface : const Color(0xFF2F2C42);
    final hintColor =
        isDark ? theme.colorScheme.onSurfaceVariant : const Color(0xFF9A91B0);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: TextField(
        controller: _otpController,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        autofocus: true,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        style: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: textColor,
          letterSpacing: 18,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: '------',
          hintStyle: GoogleFonts.inter(
            fontSize: 28,
            letterSpacing: 18,
            color: hintColor,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Text(
        _errorMessage!,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF991B1B),
        ),
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required VoidCallback? onPressed,
    required bool isDark,
    required ThemeData theme,
  }) {
    final buttonColor =
        isDark ? theme.colorScheme.primary : const Color(0xFF41315D);
    final buttonTextColor =
        isDark ? theme.colorScheme.onPrimary : Colors.white;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          disabledBackgroundColor: buttonColor.withValues(alpha: 0.6),
          foregroundColor: buttonTextColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: buttonTextColor,
                ),
              )
            : Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}
