import 'dart:async'; // For animations
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:coachmint/utils/routes.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import for specific errors

import 'package:coachmint/utils/colors.dart';

import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();

  final RxBool _isLoading = false.obs;
  final RxBool _isPasswordVisible = false.obs; // NEW: For show/hide password

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    super.dispose();
  }

  // --- STYLED HELPER for Input Decorations (Matches LoginScreen) ---
  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.secondaryText),
      prefixIcon: Icon(icon, color: AppColors.secondaryText, size: 20),
      filled: true,
      fillColor: AppColors.cardBackground,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.redAccent, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.redAccent, width: 2),
      ),
    );
  }

  // --- STYLED HELPER for Snackbars ---
  void _showErrorSnackbar(String message) {
    Get.snackbar(
      "Registration Failed",
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.redAccent,
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
      borderRadius: 12,
      icon: const Icon(Icons.error_outline, color: Colors.white),
    );
  }

  // --- UPDATED: Registration Logic with Better Error Handling ---
  Future<void> _registerUser() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    _isLoading.value = true;
    try {
      await _authService.registerWithEmailPassword(
        emailController.text.trim(),
        passwordController.text.trim(),
        nameController.text.trim(),
      );

      Get.snackbar(
        "Success!",
        "Account created. Welcome to CoachMint!",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.greenAccent,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        borderRadius: 12,
        icon: const Icon(Icons.check_circle_outline, color: Colors.white),
      );

      Get.offAllNamed(AppRoutes.onboarding);
    } on FirebaseAuthException catch (e) {
      String msg = "Something went wrong. Please try again.";
      if (e.code == 'weak-password') {
        msg = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        msg = 'An account already exists for that email.';
      } else if (e.code == 'invalid-email') {
        msg = 'The email address is not valid.';
      }
      _showErrorSnackbar(msg);
    } catch (e) {
      _showErrorSnackbar("An unexpected error occurred.");
    } finally {
      _isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Sign Up"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.secondaryText),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- STAGGERED ANIMATION 1 ---
              _AnimatedFormItem(
                delay: const Duration(milliseconds: 100),
                child: Text(
                  "Create an Account",
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.mainText,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              _AnimatedFormItem(
                delay: const Duration(milliseconds: 200),
                child: Text(
                  "Start your financial journey with us.",
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppColors.secondaryText,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 48),

              // --- STAGGERED ANIMATION 2: Name ---
              _AnimatedFormItem(
                delay: const Duration(milliseconds: 300),
                child: TextFormField(
                  controller: nameController,
                  style: GoogleFonts.inter(color: AppColors.mainText),
                  decoration: _buildInputDecoration(
                    "Full Name",
                    Icons.person_outline,
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? "Please enter your name"
                      : null,
                ),
              ),
              const SizedBox(height: 20),

              // --- STAGGERED ANIMATION 3: Email ---
              _AnimatedFormItem(
                delay: const Duration(milliseconds: 400),
                child: TextFormField(
                  controller: emailController,
                  style: GoogleFonts.inter(color: AppColors.mainText),
                  decoration: _buildInputDecoration(
                    "Email",
                    Icons.email_outlined,
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v == null || !GetUtils.isEmail(v.trim())
                      ? "Please enter a valid email"
                      : null,
                ),
              ),
              const SizedBox(height: 20),

              // --- STAGGERED ANIMATION 4: Password ---
              _AnimatedFormItem(
                delay: const Duration(milliseconds: 500),
                child: Obx(() => TextFormField(
                  controller: passwordController,
                  style: GoogleFonts.inter(color: AppColors.mainText),
                  decoration: _buildInputDecoration(
                    "Password",
                    Icons.lock_outline,
                  ).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible.value
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.secondaryText,
                      ),
                      onPressed: () {
                        _isPasswordVisible.value =
                        !_isPasswordVisible.value;
                      },
                    ),
                  ),
                  obscureText: !_isPasswordVisible.value,
                  validator: (v) => v == null || v.length < 6
                      ? "Password must be at least 6 characters"
                      : null,
                )),
              ),
              const SizedBox(height: 40),

              // --- STAGGERED ANIMATION 5: Button ---
              _AnimatedFormItem(
                delay: const Duration(milliseconds: 600),
                child: Obx(() => SizedBox(
                  height: 56, // Increased height for better tap target
                  child: ElevatedButton(
                    onPressed: _isLoading.value ? null : _registerUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor:
                      AppColors.primary.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    // --- ENGAGING: Smooth loading animation ---
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                            opacity: animation, child: child);
                      },
                      child: _isLoading.value
                          ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white),
                          strokeWidth: 3,
                        ),
                      )
                          : Text(
                        'Create Account',
                        key: const ValueKey('text'),
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                )),
              ),
              const SizedBox(height: 32),

              // --- STAGGERED ANIMATION 6: Footer ---
              _AnimatedFormItem(
                delay: const Duration(milliseconds: 700),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Already have an account?",
                      style: GoogleFonts.inter(color: AppColors.secondaryText),
                    ),
                    TextButton(
                      onPressed:
                      _isLoading.value ? null : () => Get.toNamed('/login'),
                      child: Text(
                        "Sign In",
                        style: GoogleFonts.inter(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- NEW: Animation Helper Widget ---
/// This widget handles the staggered fade-in and slide-up animation.
class _AnimatedFormItem extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _AnimatedFormItem({
    required this.child,
    required this.delay,
  });

  @override
  State<_AnimatedFormItem> createState() => _AnimatedFormItemState();
}

class _AnimatedFormItemState extends State<_AnimatedFormItem> {
  double _opacity = 0.0;
  Offset _offset = const Offset(0, 0.2);

  @override
  void initState() {
    super.initState();
    // Start the animation after the specified delay
    Timer(widget.delay, () {
      if (mounted) {
        setState(() {
          _opacity = 1.0;
          _offset = Offset.zero;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _offset,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}