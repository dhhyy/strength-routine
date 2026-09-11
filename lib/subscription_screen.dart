import 'package:flutter/material.dart';
import 'data/app_storage.dart';
import 'data/text_store.dart';
import 'flow_components.dart';
import 'support_screen.dart';
import 'tokens.dart';
import 'widgets.dart';

const _trialDays = 7;

/// 스토어 결제 전: 로컬 7일 체험 타이머만 안내한다. 권한 게이트는 아직 없다.
class SubscriptionScreen extends StatefulWidget {
  final TextStore? trialStore;
  const SubscriptionScreen({super.key, this.trialStore});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  DateTime? _started;
  bool _loading = true;
  TextStore? _store;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<TextStore> _trialStore() async {
    if (_store != null) return _store!;
    if (widget.trialStore != null) {
      return _store = widget.trialStore!;
    }
    return _store = (await AppStorage.open()).trial;
  }

  Future<void> _load() async {
    try {
      final store = await _trialStore();
      if (await store.exists()) {
        _started = DateTime.tryParse((await store.read()).trim());
      }
    } catch (_) {
      _started = null;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _startTrial() async {
    final now = DateTime.now().toUtc();
    final store = await _trialStore();
    await store.write(now.toIso8601String());
    if (!mounted) return;
    setState(() => _started = now);
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _started == null
        ? null
        : _trialDays - DateTime.now().toUtc().difference(_started!).inDays;
    return FlowPage(
      title: '구독 안내',
      children: [
        if (_loading) const LinearProgressIndicator(),
        const StatePanel(
          title: '스토어 결제는 준비 중이에요',
          message:
              '실제 결제·복원·만료는 아직 연결되지 않았어요. 아래 7일 체험은 이 기기에서만 세는 안내 타이머입니다.',
          icon: Icons.info_outline,
        ),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('로컬 7일 체험 타이머', style: AppType.heading),
              const SizedBox(height: AppSpace.x3),
              if (_started == null)
                Text(
                  '원문 브리프의 “1주 체험” 자리를 로컬로만 표시합니다. 기능을 막지 않아요.',
                  style: AppType.body,
                )
              else
                Text(
                  remaining != null && remaining > 0
                      ? '체험 시작 후 약 $remaining일 남음 (로컬 기준)'
                      : '로컬 체험 기간이 지났어요. 기능은 그대로 쓸 수 있어요.',
                  style: AppType.body,
                ),
              const SizedBox(height: AppSpace.x4),
              if (_started == null)
                PrimaryAction(label: '7일 체험 시작하기', onPressed: _startTrial),
            ],
          ),
        ),
        PrimaryAction(
          label: '문의하기',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SupportScreen()),
          ),
        ),
      ],
    );
  }
}
