import 'package:flutter/material.dart';
import '../tokens.dart';
import 'auth_controller.dart';

/// 로그인 전용 화면. 카카오 한 가지. 성공 세션은 AuthController가 보관.
class LoginScreen extends StatefulWidget {
  final AuthController auth;
  final VoidCallback? onSignedIn;
  const LoginScreen({super.key, required this.auth, this.onSignedIn});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_onAuth);
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuth);
    super.dispose();
  }

  void _onAuth() {
    if (!mounted) return;
    setState(() {});
    if (widget.auth.isSignedIn) {
      widget.onSignedIn?.call();
      if (Navigator.of(context).canPop()) Navigator.of(context).pop(true);
    }
  }

  Future<void> _kakao() async {
    await widget.auth.signInWithKakao();
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.screen),
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppGradients.glow),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 22 + bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    color: AppColors.inkDim,
                  ),
                  const Spacer(flex: 2),
                  Text('로그인', style: kr(size: 28, weight: FontWeight.w700, spacing: -0.4)),
                  const SizedBox(height: 10),
                  Text('이미 만든 계정으로 이어서 훈련해요.',
                      style: kr(size: 14, color: AppColors.inkDim).copyWith(height: 1.5)),
                  const SizedBox(height: 36),
                  _KakaoButton(busy: auth.busy, onPressed: auth.busy ? null : _kakao),
                  if (auth.canBypass) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: GestureDetector(
                        onTap: auth.busy
                            ? null
                            : () async {
                                await auth.signInBypass();
                              },
                        child: Text('테스트로 시작 (인증 없음)',
                            style: kr(size: 13, color: AppColors.muted)),
                      ),
                    ),
                  ],
                  if (auth.error != null) ...[
                    const SizedBox(height: 14),
                    Text(auth.error!, style: kr(size: 12, color: AppColors.warn).copyWith(height: 1.4)),
                  ],
                  const Spacer(flex: 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KakaoButton extends StatelessWidget {
  final bool busy;
  final VoidCallback? onPressed;
  const _KakaoButton({required this.busy, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFEE500),
      borderRadius: BorderRadius.circular(AppRadius.ctrl),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.ctrl),
        onTap: onPressed,
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF191600)),
                  )
                : Text('카카오로 계속하기',
                    style: kr(size: 15, weight: FontWeight.w700, color: const Color(0xFF191600))),
          ),
        ),
      ),
    );
  }
}
