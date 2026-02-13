import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/glow_button.dart';
import '../../shell/main_shell.dart';
import 'auth_provider.dart';
import 'otp_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _useEmail = false;
  bool _isRegister = false;

  // Phone
  final _phoneFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  String _countryCode = '+254';

  // Email
  final _emailFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  static const List<String> _countryCodes = [
    '+254',
    '+255',
    '+256',
    '+251',
    '+250',
    '+243',
    '+234',
    '+233',
    '+27',
    '+1',
    '+44',
  ];

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_phoneFormKey.currentState!.validate()) return;

    final phone = Validators.normalizeKenyanPhone(_phoneController.text.trim());
    final fullPhone = phone.startsWith('+254')
        ? phone
        : '$_countryCode${_phoneController.text.trim()}';

    final auth = context.read<AuthProvider>();
    auth.clearError();
    await auth.sendOtp(fullPhone);

    if (!mounted) return;

    if (auth.status == AuthStatus.otpSent) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => OtpScreen(phoneNumber: fullPhone)),
      );
    }
  }

  Future<void> _submitEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    auth.clearError();

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (_isRegister) {
      await auth.signUpEmail(email, password);
    } else {
      await auth.signInEmail(email, password);
    }

    if (!mounted) return;

    if (auth.status == AuthStatus.authenticated) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
    }
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
                    const SizedBox(height: 48),
                    _buildLogo(context),
                    const SizedBox(height: 32),

                    // Error message
                    if (auth.errorMessage != null) ...[
                      _buildError(auth.errorMessage!),
                      const SizedBox(height: 16),
                    ],

                    // Phone or Email mode
                    _useEmail ? _buildEmailForm(auth) : _buildPhoneForm(auth),

                    const SizedBox(height: 24),

                    // Toggle mode
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _useEmail = !_useEmail;
                        });
                        context.read<AuthProvider>().clearError();
                      },
                      child: Text(
                        _useEmail
                            ? 'Use phone number instead'
                            : 'Use email instead',
                        style: const TextStyle(
                          color: AppColors.cyan,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.neonGreen, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.neonGreen.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.eco_rounded,
            size: 40,
            color: AppColors.neonGreen,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'SMART FARMER',
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            color: AppColors.neonGreen,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _useEmail ? 'Sign in with email' : 'Sign in with phone',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildError(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneForm(AuthProvider auth) {
    return Form(
      key: _phoneFormKey,
      child: Column(
        children: [
          // Country code + phone
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Country code dropdown
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _countryCode,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(
                      color: AppColors.neonGreen,
                      fontSize: 16,
                    ),
                    items: _countryCodes.map((code) {
                      return DropdownMenuItem(value: code, child: Text(code));
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _countryCode = v);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Phone input
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: AppColors.white, fontSize: 16),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d\s\-]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    hintText: '0712 345 678',
                    prefixIcon: Icon(
                      Icons.phone_android,
                      color: AppColors.neonGreen,
                    ),
                  ),
                  validator: Validators.phone,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: GlowButton(
              label: auth.isLoading ? 'SENDING...' : 'SEND OTP',
              icon: Icons.sms_rounded,
              onPressed: auth.isLoading ? () {} : _sendOtp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailForm(AuthProvider auth) {
    return Form(
      key: _emailFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: AppColors.white, fontSize: 16),
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'farmer@example.com',
              prefixIcon: Icon(Icons.email_outlined, color: AppColors.cyan),
            ),
            validator: Validators.email,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(color: AppColors.white, fontSize: 16),
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_outline, color: AppColors.cyan),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textSecondary,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
            ),
            validator: Validators.password,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: GlowButton(
              label: auth.isLoading
                  ? 'PLEASE WAIT...'
                  : _isRegister
                  ? 'CREATE ACCOUNT'
                  : 'SIGN IN',
              icon: _isRegister
                  ? Icons.person_add_rounded
                  : Icons.login_rounded,
              glowColor: AppColors.cyan,
              onPressed: auth.isLoading ? () {} : _submitEmail,
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              setState(() => _isRegister = !_isRegister);
              context.read<AuthProvider>().clearError();
            },
            child: Text(
              _isRegister
                  ? 'Already have an account? Sign in'
                  : 'No account? Create one',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
