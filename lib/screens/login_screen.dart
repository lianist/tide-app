import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/capture_mode.dart';
import '../models/hotkey_config.dart';
import '../services/auth_service.dart';
import '../theme/tide_colors.dart';
import '../widgets/hotkey_badge.dart';

/// Login screen. Sign-in is browser-based with a deep link back into the
/// app (`AUTH-3` in the guideline doc) — see `AuthService.signIn()`.
///
/// Styled to match dochi's own auth screens (`app/(auth)/layout.tsx`): Mist
/// page background, a white bordered card with **no shadow** (Tide rule —
/// the card's border does that job), and a single indigo primary button.
class LoginScreen extends StatefulWidget {
  final List<HotkeyConfig> hotkeys;
  final VoidCallback onLoginSuccess;

  const LoginScreen({
    super.key,
    required this.hotkeys,
    required this.onLoginSuccess,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  bool _isSigningIn = false;
  String? _error;

  Future<void> _handleSignIn() async {
    setState(() {
      _isSigningIn = true;
      _error = null;
    });

    final error = await _authService.signIn();
    if (!mounted) return;

    if (error == null) {
      widget.onLoginSuccess();
      return;
    }
    setState(() {
      _isSigningIn = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TideColors.bgPage,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset('assets/brand/tide-wordmark.svg', height: 24),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: TideColors.bgSurface,
                  borderRadius: BorderRadius.circular(14), // rounded-card
                  border: Border.all(color: TideColors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Tide',
                      style: TextStyle(
                        fontSize: 24,
                        height: 32 / 24,
                        fontWeight: FontWeight.w700,
                        color: TideColors.text,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sign in to sync captures with your dashboard.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, height: 20 / 13, color: TideColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 36,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: TideColors.brand,
                          foregroundColor: TideColors.onBrand,
                          disabledBackgroundColor: TideColors.bgSubtle,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ).copyWith(
                          overlayColor: WidgetStateProperty.all(TideColors.brandHover.withValues(alpha: 0.15)),
                        ),
                        onPressed: _isSigningIn ? null : _handleSignIn,
                        child: _isSigningIn
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: TideColors.onBrand,
                                ),
                              )
                            : const Text('Sign In'),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: TideColors.errorBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, color: TideColors.errorText),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Global shortcuts',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: TideColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: widget.hotkeys.map((config) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${config.action.displayName}  ',
                        style: const TextStyle(
                          fontSize: 12,
                          color: TideColors.textSecondary,
                        ),
                      ),
                      HotkeyBadge(shortcutText: config.shortcutDisplay),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
