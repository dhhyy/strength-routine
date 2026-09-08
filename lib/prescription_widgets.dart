import 'package:flutter/material.dart';

import 'domain/training_program.dart';
import 'tokens.dart';

String setKindLabel(ProgramSetKind kind) => switch (kind) {
  ProgramSetKind.work => '작업 세트',
  ProgramSetKind.warmup => '워밍업',
  ProgramSetKind.drop => '드롭세트',
};

String repetitionLabel(ProgramSet set) => set.isAmrap
    ? 'AMRAP · 기준 ${set.repetitions}회'
    : '${set.repetitions}${set.repetitionsMax == null ? '' : '–${set.repetitionsMax}'}회';

List<InlineSpan> repetitionSpans(ProgramSet set) => [
  if (set.isAmrap) ...[
    TextSpan(
      text: 'AMRAP · ',
      style: mono(color: AppColors.inkDim),
    ),
    const TextSpan(text: '기준 '),
  ],
  TextSpan(
    text:
        '${set.repetitions}${set.repetitionsMax == null ? '' : '–${set.repetitionsMax}'}',
    style: mono(color: AppColors.inkDim),
  ),
  const TextSpan(text: '회'),
];

/// Shared authored instructions: never inferred from actual repetitions or RIR.
class SetPrescriptionNotes extends StatelessWidget {
  final ProgramSet set;
  final bool explain;
  const SetPrescriptionNotes({
    super.key,
    required this.set,
    this.explain = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (set.kind != ProgramSetKind.work)
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.x2),
          child: Text(
            setKindLabel(set.kind),
            style: AppType.caption.copyWith(color: AppColors.accent),
          ),
        ),
      if (explain && set.kind == ProgramSetKind.drop)
        Text(
          '작성된 순서와 중량대로 각 세트를 수행해 주세요. 자동 중량 감소는 적용하지 않아요.',
          style: AppType.caption,
        ),
      if (set.restSeconds != null || set.tempo != null)
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.x2),
          child: Text.rich(
            TextSpan(
              style: AppType.caption,
              children: [
                if (set.restSeconds != null) ...[
                  const TextSpan(text: '세트 후 휴식 '),
                  TextSpan(
                    text: '${set.restSeconds}',
                    style: mono(color: AppColors.muted),
                  ),
                  const TextSpan(text: '초'),
                ],
                if (set.restSeconds != null && set.tempo != null)
                  const TextSpan(text: ' · '),
                if (set.tempo != null) ...[
                  const TextSpan(text: '템포 '),
                  TextSpan(
                    text: set.tempo,
                    style: mono(color: AppColors.muted),
                  ),
                ],
              ],
            ),
          ),
        ),
      if (explain && set.tempo != null)
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.x2),
          child: Text(
            '템포: 편심 → 하단 정지 → 구심 → 상단 정지 순서의 초 단위예요. X는 빠르게 수행하는 구심 구간이에요.',
            style: AppType.caption,
          ),
        ),
      if (explain && set.isAmrap)
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.x2),
          child: Text(
            'AMRAP: 가능한 반복을 수행하고 실제 횟수를 입력해 주세요. 기준 반복은 최소 완료 조건이 아니며, RIR 처방은 별도로 확인해 주세요.',
            style: AppType.caption,
          ),
        ),
    ],
  );
}

class SupersetNote extends StatelessWidget {
  final String? group;
  const SupersetNote({super.key, required this.group});
  @override
  Widget build(BuildContext context) => group == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: AppSpace.x2),
          child: Text.rich(
            TextSpan(
              style: AppType.caption,
              children: [
                const TextSpan(text: '슈퍼세트 '),
                TextSpan(
                  text: group,
                  style: AppType.caption.copyWith(color: AppColors.accent),
                ),
                const TextSpan(text: ' · 같은 그룹의 운동을 한 세트씩 번갈아 진행'),
              ],
            ),
          ),
        );
}
