import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/webview2_runtime.dart';
import '../theme/tide_colors.dart';

/// Shown in place of the dashboard when the Edge WebView2 Runtime is missing.
///
/// Without this the same situation is a blank white rectangle: the app looks
/// broken, and nothing on screen distinguishes a missing browser component
/// from a dead network, a failed login or a crash. Naming it is the whole
/// point — the fix is a two-minute download, but only for someone who knows
/// that is what they need.
///
/// Styled like [LoginScreen] because it stands in the same place: the whole
/// window, before there is any dashboard to show.
class WebView2MissingScreen extends StatelessWidget {
  /// Re-runs the check and rebuilds the dashboard when the runtime turns up.
  final VoidCallback onRecheck;

  /// The last recheck came back empty-handed. Without saying so, pressing the
  /// button on a machine that still has no runtime looks like a dead button.
  final bool stillMissing;

  const WebView2MissingScreen({
    super.key,
    required this.onRecheck,
    this.stillMissing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TideColors.bgPage,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset('assets/brand/tide-logo-horizontal.svg', height: 28),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: TideColors.bgSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: TideColors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '대시보드를 열려면\nMicrosoft Edge WebView2가 필요합니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 22 / 14,
                        fontWeight: FontWeight.w600,
                        color: TideColors.text,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Windows가 기본으로 갖추고 있는 구성 요소인데, '
                      '이 PC에는 설치되어 있지 않습니다. '
                      'Microsoft에서 무료로 받을 수 있습니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 18 / 12,
                        color: TideColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 36,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: TideColors.brand,
                          foregroundColor: TideColors.onBrand,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () => launchUrl(
                          WebView2Runtime.downloadUrl,
                          mode: LaunchMode.externalApplication,
                        ),
                        child: const Text('다운로드 페이지 열기'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 36,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: TideColors.text,
                          side: const BorderSide(color: TideColors.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(fontSize: 14),
                        ),
                        onPressed: onRecheck,
                        child: const Text('설치했습니다 · 다시 확인'),
                      ),
                    ),
                    if (stillMissing) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: TideColors.errorBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '아직 찾지 못했습니다. 설치를 마친 뒤 다시 눌러 주세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: TideColors.errorText,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '캡처 단축키는 지금도 동작합니다.',
                style: TextStyle(fontSize: 12, color: TideColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
