import 'package:flutter/material.dart';
import '../tokens.dart';
import 'auth_controller.dart';
import 'login_screen.dart';

/// 간단 가입: 필수 약관 → 카카오. Toss Agreement 톤(필수/선택 분리 + 체크 모션).
class SignupScreen extends StatefulWidget {
  final AuthController auth;
  final VoidCallback? onSignedIn;
  const SignupScreen({super.key, required this.auth, this.onSignedIn});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool _all = false;
  bool _terms = false;
  bool _privacy = false;
  bool _marketing = false;
  final _shake = [0.0, 0.0, 0.0];

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

  void _syncAll() {
    _all = _terms && _privacy;
    // marketing is optional — all-required means terms+privacy only
  }

  void _toggleAll(bool value) {
    setState(() {
      _all = value;
      _terms = value;
      _privacy = value;
      if (!value) _marketing = false;
      if (value) {
        /* keep marketing as user left it when unchecking all only */
      }
    });
  }

  Future<void> _shakeRequired() async {
    for (var i = 0; i < 3; i++) {
      setState(() => _shake[i] = 6);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      setState(() => _shake[i] = -6);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      setState(() => _shake[i] = 0);
    }
  }

  Future<void> _continue() async {
    if (!_terms || !_privacy) {
      await _shakeRequired();
      return;
    }
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
                  const SizedBox(height: 12),
                  Text('간단하게 가입하기',
                      style: kr(size: 26, weight: FontWeight.w700, spacing: -0.4)),
                  const SizedBox(height: 10),
                  Text('약관에 동의한 뒤 카카오로 바로 시작해요.',
                      style: kr(size: 14, color: AppColors.inkDim).copyWith(height: 1.5)),
                  const SizedBox(height: 28),
                  _AgreeRow(
                    label: '전체 동의',
                    strong: true,
                    checked: _all,
                    offset: _shake[0],
                    onChanged: _toggleAll,
                  ),
                  const Divider(height: 28, color: AppColors.hairStrong),
                  _AgreeRow(
                    label: '[필수] 이용약관',
                    checked: _terms,
                    offset: _shake[1],
                    onChanged: (v) => setState(() {
                      _terms = v;
                      _syncAll();
                    }),
                  ),
                  const SizedBox(height: 10),
                  _AgreeRow(
                    label: '[필수] 개인정보 처리방침',
                    checked: _privacy,
                    offset: _shake[2],
                    onChanged: (v) => setState(() {
                      _privacy = v;
                      _syncAll();
                    }),
                  ),
                  const SizedBox(height: 10),
                  _AgreeRow(
                    label: '[선택] 마케팅 정보 수신',
                    checked: _marketing,
                    onChanged: (v) => setState(() => _marketing = v),
                  ),
                  const Spacer(),
                  if (auth.error != null) ...[
                    Text(auth.error!, style: kr(size: 12, color: AppColors.warn).copyWith(height: 1.4)),
                    const SizedBox(height: 12),
                  ],
                  _PrimaryCta(
                    label: '카카오로 가입하기',
                    busy: auth.busy,
                    enabled: _terms && _privacy,
                    onPressed: auth.busy ? null : _continue,
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => LoginScreen(
                              auth: widget.auth,
                              onSignedIn: widget.onSignedIn,
                            ),
                          ),
                        );
                      },
                      child: Text('이미 계정이 있어요 · 로그인',
                          style: kr(size: 13, color: AppColors.muted)),
                    ),
                  ),
                  if (auth.canBypass) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: GestureDetector(
                        onTap: auth.busy
                            ? null
                            : () async {
                                await auth.signInBypass();
                              },
                        child: Text('테스트로 시작 (인증 없음)',
                            style: kr(size: 12, color: AppColors.muted)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AgreeRow extends StatelessWidget {
  final String label;
  final bool checked;
  final bool strong;
  final double offset;
  final ValueChanged<bool> onChanged;
  const _AgreeRow({
    required this.label,
    required this.checked,
    required this.onChanged,
    this.strong = false,
    this.offset = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(offset, 0),
      child: InkWell(
        onTap: () => onChanged(!checked),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: checked ? AppGradients.accent : null,
                  color: checked ? null : AppColors.fill,
                  border: checked ? null : Border.all(color: AppColors.hairStrong),
                ),
                child: checked
                    ? const Icon(Icons.check_rounded, size: 16, color: AppColors.ctaInk)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: kr(
                    size: strong ? 15 : 13,
                    weight: strong ? FontWeight.w700 : FontWeight.w500,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryCta extends StatelessWidget {
  final String label;
  final bool busy;
  final bool enabled;
  final VoidCallback? onPressed;
  const _PrimaryCta({
    required this.label,
    required this.busy,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled || busy ? 1 : 0.45,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppGradients.accent,
          borderRadius: BorderRadius.circular(AppRadius.ctrl),
          boxShadow: enabled ? AppShadow.glow(AppColors.ctaGlow, blur: 26, spread: -8) : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.ctrl),
            onTap: enabled ? onPressed : onPressed,
            child: SizedBox(
              height: 52,
              width: double.infinity,
              child: Center(
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.ctaInk),
                      )
                    : Text(label,
                        style: mono(size: 15, weight: FontWeight.w600, color: AppColors.ctaInk)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
