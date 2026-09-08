import 'package:flutter/material.dart';
import 'flow_components.dart';
import 'support_screen.dart';
import 'tokens.dart';
import 'widgets.dart';

/// 결제 권한을 흉내 내지 않고 현재 제공 범위를 안내한다.
class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) => FlowPage(
    title: '구독 안내',
    children: [
      const StatePanel(
        title: '구독은 준비 중이에요',
        message: '구독 상품을 준비하고 있어요. 아직 앱에서 결제를 시작할 수 없어요.',
        icon: Icons.info_outline,
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
