import 'package:flutter/material.dart';
import 'flow_components.dart';
import 'tokens.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  static const _answers = [
    (
      question: '지금 구독할 수 있나요?',
      answer:
          '구독 상품은 아직 준비 중이에요. 현재 앱에는 구매·무료 체험 시작·자동 결제 기능이 없어요. 가격과 정기 제공 콘텐츠는 출시 전에 안내할 예정이에요.',
    ),
    (
      question: '구독 해지와 구매 복원은 어디서 하나요?',
      answer:
          '현재 앱은 구독을 판매하지 않아 해지나 구매 복원 기능도 연결되어 있지 않아요. 이 화면에서는 요청을 접수하지 않아요. 다른 앱에서 결제한 구독은 해당 스토어의 구독 관리에서 확인해 주세요.',
    ),
    (
      question: '운동 기록은 어디에 저장되나요?',
      answer:
          '저장에 성공한 기록과 초안은 이 기기에 남아요. 저장 오류가 보이면 재시도해 주세요. 클라우드 백업과 다른 기기 동기화는 없으며, 앱 삭제나 기기 변경 시 자동으로 옮겨지지 않아요.',
    ),
    (
      question: '기본 단위를 바꾸면 기존 기록도 바뀌나요?',
      answer:
          '기본 단위는 새 세트와 최근 기록의 첫 입력에만 적용돼요. 작성 중인 초안과 기존 실제 기록의 숫자·단위는 그대로 유지해요. 입력 중 단위를 바꾸어도 숫자를 자동 환산하지 않아요.',
    ),
    (
      question: '이전 프로그램의 초안을 수정할 수 있나요?',
      answer:
          '기록 달력에서 보관된 프로그램의 초안을 읽을 수 있어요. 보관 초안은 작성 중인 입력이며 완료 기록이 아니에요. 현재는 읽기 전용이라 수정·완료·제외로 바꿀 수 없어요.',
    ),
    (
      question: '트레이너에게 질문을 보낼 수 있나요?',
      answer:
          '한 명의 트레이너가 프로그램을 운영할 예정이에요. 현재는 이 도움말만 제공하며 문의 전송이나 실시간 상담은 지원하지 않아요. 문의 채널과 답변 범위는 준비된 뒤 안내할게요.',
    ),
  ];

  @override
  Widget build(BuildContext context) => FlowPage(
    title: '도움말',
    children: [
      Text('기록과 구독에 관해 자주 묻는 내용을 모았어요.', style: AppType.body),
      for (final item in _answers)
        ExpansionTile(
          key: ValueKey(item.question),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: AppSpace.x4),
          title: Text(item.question, style: AppType.action),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(item.answer, style: AppType.body),
            ),
          ],
        ),
      Text('이 도움말은 앱에 포함되어 있어요. 문의가 접수되거나 전송되지는 않아요.', style: AppType.caption),
    ],
  );
}
