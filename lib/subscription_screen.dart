import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'flow_components.dart';
import 'support_screen.dart';
import 'tokens.dart';
import 'widgets.dart';

const _trialDays = 7;

/// 스토어 결제 전: 로컬 7일 체험 타이머만 안내한다. 권한 게이트는 아직 없다.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  DateTime? _started;
  bool _loading = true;
  File? _file;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<File> _trialFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationSupportDirectory();
    return _file = File('${dir.path}/local-trial-started.txt');
  }

  Future<void> _load() async {
    try {
      final file = await _trialFile();
      if (await file.exists()) {
        _started = DateTime.tryParse((await file.readAsString()).trim());
      }
    } catch (_) {
      _started = null;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _startTrial() async {
    final now = DateTime.now().toUtc();
    final file = await _trialFile();
    await file.writeAsString(now.toIso8601String());
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
              else if (remaining != null && remaining > 0)
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '남은 안내 일수 ', style: AppType.body),
                      TextSpan(text: '$remaining', style: AppType.number),
                      TextSpan(text: '일', style: AppType.body),
                    ],
                  ),
                )
              else
                Text(
                  '로컬 체험 안내 기간이 지났어요. 결제 연동 전까지 기록은 계속 쓸 수 있어요.',
                  style: AppType.body,
                ),
              if (_started == null) ...[
                const SizedBox(height: AppSpace.x4),
                PrimaryAction(
                  label: '로컬 체험 타이머 시작',
                  onPressed: _loading ? null : _startTrial,
                ),
              ],
            ],
          ),
        ),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('내 기록은 계속 확인할 수 있어요', style: AppType.heading),
              const SizedBox(height: AppSpace.x3),
              Text('현재 기기에 저장한 운동 기록과 초안은 구독 없이 열람할 수 있어요.', style: AppType.body),
              const SizedBox(height: AppSpace.x2),
              Text(
                '기기 저장은 클라우드 백업과 달라요. 앱 삭제나 기기 변경 시 자동 복원되지 않아요.',
                style: AppType.caption,
              ),
            ],
          ),
        ),
        Text('가격과 제공 콘텐츠는 구독 출시 전에 안내할 예정이에요.', style: AppType.body),
        PrimaryAction(
          label: '구독·기록 도움말',
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SupportScreen())),
        ),
      ],
    );
  }
}
