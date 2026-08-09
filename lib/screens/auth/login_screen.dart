import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../support/support_screen.dart';

// ─────────────────────────────────────────────────────────
// LoginScreen
// First Name + Phone + PIN (4-digit)
// Uses authProvider (Riverpod)
// ─────────────────────────────────────────────────────────
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  // Form
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();

  // UI State
  bool _obscurePin = true;
  bool _isRegisterMode = false;
  final _lastNameController = TextEditingController();

  // Animation
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  // ── Submit ─────────────────────────────────────────────
  Future<void> _submit() async {
    // Clear any previous error
    ref.read(authProvider.notifier).clearError();

    if (!_formKey.currentState!.validate()) return;

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    bool success;

    if (_isRegisterMode) {
      success = await ref.read(authProvider.notifier).register(
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            phone: _phoneController.text.trim(),
            pin: _pinController.text.trim(),
          );
    } else {
      success = await ref.read(authProvider.notifier).login(
            firstName: _firstNameController.text.trim(),
            phone: _phoneController.text.trim(),
            pin: _pinController.text.trim(),
          );
    }

    // Navigation is handled by main.dart watching authProvider
    // If success == false, error is shown via authProvider.state.errorMessage
    if (!success && mounted) {
      // Shake the form slightly on error
      _fadeController.reset();
      _fadeController.forward();
    }
  }

  // ── Toggle Login / Register ────────────────────────────
  void _toggleMode() {
    ref.read(authProvider.notifier).clearError();
    setState(() {
      _isRegisterMode = !_isRegisterMode;
      _formKey.currentState?.reset();
      _firstNameController.clear();
      _lastNameController.clear();
      _phoneController.clear();
      _pinController.clear();
    });
    _fadeController.reset();
    _fadeController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;
    final errorMessage = authState.errorMessage;

    return Scaffold(
      backgroundColor: AppTheme.primaryBlue,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    MediaQuery.of(context).padding.top -
                    MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Top Hero Section ───────────────────
                  _buildHeroSection(),

                  // ── Form Card ─────────────────────────
                  _buildFormCard(
                    isLoading: isLoading,
                    errorMessage: errorMessage,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Hero Section (Logo + Title) ────────────────────────
  Widget _buildHeroSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
      child: Column(
        children: [
          // Logo
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.12),
              border: Border.all(
                color: AppTheme.accentGold.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/nggc-logo.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.church,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // App name
          const Text(
            'NGGC',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 6,
            ),
          ),

          const SizedBox(height: 6),

          // Tagline
          const Text(
            'Sunday School',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.accentGold,
              fontStyle: FontStyle.italic,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  // ── Form Card ──────────────────────────────────────────
  Widget _buildFormCard({
    required bool isLoading,
    required String? errorMessage,
  }) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Mode Title ─────────────────────────────
            Text(
              _isRegisterMode ? 'Create Account' : 'Welcome Back',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 6),

            Text(
              _isRegisterMode
                  ? 'Register to join Sunday School'
                  : 'Sign in to continue',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 28),

            // ── Error Banner ───────────────────────────
            if (errorMessage != null && errorMessage.isNotEmpty)
              _buildErrorBanner(errorMessage),

            // ── First Name ─────────────────────────────
            _buildLabel('First Name'),
            const SizedBox(height: 6),
            TextFormField(
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
              controller: _firstNameController,
              enabled: !isLoading,
              textCapitalization: TextCapitalization.words,
              keyboardType: TextInputType.name,
              textInputAction: _isRegisterMode
                  ? TextInputAction.next
                  : TextInputAction.next,
              decoration: _inputDecoration(
                hint: 'e.g. John',
                icon: Icons.person_outline,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter your first name';
                }
                if (v.trim().length < 2) {
                  return 'First name must be at least 2 characters';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // ── Last Name (Register only) ───────────────
            if (_isRegisterMode) ...[
              _buildLabel('Last Name'),
              const SizedBox(height: 6),
              TextFormField(
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                controller: _lastNameController,
                enabled: !isLoading,
                textCapitalization: TextCapitalization.words,
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
                decoration: _inputDecoration(
                  hint: 'e.g. Doe',
                  icon: Icons.person_outline,
                ),
                validator: (v) {
                  if (_isRegisterMode && (v == null || v.trim().isEmpty)) {
                    return 'Please enter your last name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],

            // ── Phone Number ────────────────────────────
            _buildLabel('Phone Number'),
            const SizedBox(height: 6),
            TextFormField(
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
              controller: _phoneController,
              enabled: !isLoading,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              decoration: _inputDecoration(
                hint: 'e.g. 07041926783',
                icon: Icons.phone_outlined,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter your phone number';
                }
                if (v.trim().length < 10) {
                  return 'Enter a valid phone number';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // ── PIN ─────────────────────────────────────
            _buildLabel(_isRegisterMode ? 'Create PIN (4 digits)' : 'PIN'),
            const SizedBox(height: 6),
            TextFormField(
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, letterSpacing: 4),
              controller: _pinController,
              enabled: !isLoading,
              obscureText: _obscurePin,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: _inputDecoration(
                hint: 'aaaa',
                icon: Icons.lock_outline,
                suffix: IconButton(
                  icon: Icon(
                    _obscurePin
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: AppTheme.textSecondary,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePin = !_obscurePin),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter your PIN';
                }
                if (v.trim().length != 4) {
                  return 'PIN must be exactly 4 digits';
                }
                return null;
              },
            ),

            const SizedBox(height: 32),

            // ── Submit Button ───────────────────────────
            _buildSubmitButton(isLoading),

            const SizedBox(height: 20),

            // ── Toggle Mode ─────────────────────────────
            _buildToggleMode(isLoading),

            const SizedBox(height: 24),

            // ── Render wake-up hint ─────────────────────
            if (isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Connecting to server...\nThis may take up to 60 seconds on first use.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // ── Support Section (Divider + Button) ─────
            const SizedBox(height: 16),
            _buildSupportSection(isLoading),
          ],
        ),
      ),
    );
  }

  // ── Support Section ────────────────────────────────────
  Widget _buildSupportSection(bool isLoading) {
    return Column(
      children: [
        // Divider
        Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                color: AppTheme.dividerColor.withOpacity(0.6),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'OR',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textHint,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                color: AppTheme.dividerColor.withOpacity(0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Support Button
        OutlinedButton.icon(
          onPressed: isLoading ? null : () => showSupportSheet(context),
          icon: const Icon(
            Icons.support_agent,
            size: 20,
            color: AppTheme.primaryBlue,
          ),
          label: const Text(
            'Need Help? Contact Support',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryBlue,
            ),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: BorderSide(
              color: AppTheme.primaryBlue.withOpacity(0.4),
              width: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  // ── Error Banner ───────────────────────────────────────
  Widget _buildErrorBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.errorRed.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppTheme.errorRed,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.errorRed,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => ref.read(authProvider.notifier).clearError(),
            child: const Icon(
              Icons.close,
              color: AppTheme.errorRed,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  // ── Submit Button ──────────────────────────────────────
  Widget _buildSubmitButton(bool isLoading) {
    return ElevatedButton(
      onPressed: isLoading ? null : _submit,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: isLoading ? 0 : 3,
      ),
      child: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            )
          : Text(
              _isRegisterMode ? 'Create Account' : 'Sign In',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
    );
  }

  // ── Toggle Login / Register ────────────────────────────
  Widget _buildToggleMode(bool isLoading) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isRegisterMode
              ? 'Already have an account? '
              : 'New to NGGC? ',
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
        GestureDetector(
          onTap: isLoading ? null : _toggleMode,
          child: Text(
            _isRegisterMode ? 'Sign In' : 'Register',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isLoading
                  ? AppTheme.textHint
                  : AppTheme.primaryBlue,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  // ── Field Label ────────────────────────────────────────
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.textPrimary,
      ),
    );
  }

  // ── Input Decoration ───────────────────────────────────
  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: AppTheme.textSecondary),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.errorRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppTheme.errorRed, width: 2),
      ),
      hintStyle: const TextStyle(
        color: AppTheme.textHint,
        fontSize: 14,
      ),
    );
  }
}