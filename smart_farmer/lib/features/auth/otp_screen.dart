import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/glow_button.dart';
import '../../shell/main_shell.dart';
import 'auth_provider.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;

  const OtpScreen({super.key, required this.phoneNumber});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  Timer? _resendTimer;
  int _resendSeconds = 30;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    _canResend = false;
    _resendSeconds = 30;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendSeconds > 0) {
          _resendSeconds--;
        } else {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verify() async {
    final code = _otpCode;
    if (Validators.otp(code) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter all 6 digits')),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    await authProvider.verifyOtp(code, phone: widget.phoneNumber);

    if (!mounted) return;

    if (authProvider.status == AuthStatus.authenticated) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
    }
  }

  Future<void> _resend() async {
    if (!_canResend) return;
    final authProvider = context.read<AuthProvider>();
    await authProvider.sendOtp(widget.phoneNumber);
    if (mounted) _startResendTimer();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppGradients.splashBackground,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Consumer<AuthProvider>(
              builder: (context, auth, _) {
                return Column(
                  children: [
                    const SizedBox(height: 60),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.cyan, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.cyan.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.sms_rounded,
                        size: 36,
                        color: AppColors.cyan,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'VERIFY OTP',
                      style: Theme.of(context).textTheme.displayMedium
                          ?.copyWith(color: AppColors.cyan, letterSpacing: 3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Enter the 6-digit code sent to',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.phoneNumber,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.neonGreen,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // OTP digit boxes
                    Form(
                      key: _formKey,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(6, (index) {
                          return SizedBox(
                            width: 45,
                            height: 56,
                            child: TextFormField(
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              maxLength: 1,
                              style: const TextStyle(
                                color: AppColors.neonGreen,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                counterText: '',
                                contentPadding: EdgeInsets.zero,
                                filled: true,
                                fillColor: AppColors.surfaceLight,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: AppColors.cyan.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: AppColors.cyan.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: AppColors.neonGreen,
                                    width: 2,
                                  ),
                                ),
                              ),
                              onChanged: (v) => _onDigitChanged(index, v),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Error message
                    if (auth.errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: AppColors.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                auth.errorMessage!,
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 32),

                    // Verify button
                    SizedBox(
                      width: double.infinity,
                      child: GlowButton(
                        label: auth.isLoading ? 'VERIFYING...' : 'VERIFY',
                        icon: Icons.verified_rounded,
                        glowColor: AppColors.cyan,
                        onPressed: auth.isLoading ? () {} : _verify,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Resend
                    _canResend
                        ? TextButton(
                            onPressed: _resend,
                            child: const Text(
                              'Resend OTP',
                              style: TextStyle(
                                color: AppColors.neonGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : Text(
                            'Resend in ${_resendSeconds}s',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                    const SizedBox(height: 16),

                    // Back
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                      label: const Text(
                        'Change phone number',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
