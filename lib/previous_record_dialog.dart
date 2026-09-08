import 'package:flutter/material.dart';
import 'domain/previous_record.dart';
import 'domain/training_program.dart';
import 'flow_components.dart';
import 'tokens.dart';

Future<PreviousSetRecord?> choosePreviousRecord(
  BuildContext context,
  List<PreviousSetRecord> records,
) => showDialog<PreviousSetRecord>(
  context: context,
  builder: (context) => AlertDialog(
    scrollable: true,
    title: Text('이전 기록 가져오기', style: AppType.heading),
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          records.isEmpty
              ? '가져올 기록이 없어요. 같은 프로그램·버전·종목의 앞선 수행일에 완료한 기록만 보여요.'
              : '최근 기록 최대 10개예요. 중량·단위·반복만 현재 입력으로 가져와요.',
          style: AppType.body,
        ),
        if (records.isNotEmpty) ...[
          const SizedBox(height: AppSpace.x3),
          Text('RIR·메모·실제 수행일은 그대로 유지해요.', style: AppType.caption),
        ],
        for (final record in records) ...[
          const SizedBox(height: AppSpace.x4),
          Text(record.programTitle, style: AppType.caption),
          Text(record.sessionTitle, style: AppType.caption),
          Text(record.exerciseName, style: AppType.body),
          Text('${record.number}세트', style: AppType.caption),
          const SizedBox(height: AppSpace.x2),
          Text('실제 수행일', style: AppType.caption),
          Text(isoDate(record.actual.performedDate!), style: AppType.number),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text:
                      '${formatNumber(record.actual.weight!)} ${record.actual.unit!.key} × ${record.actual.repetitions}',
                  style: AppType.number,
                ),
                TextSpan(text: '회', style: AppType.body),
              ],
            ),
          ),
          OutlinedButton(
            key: ValueKey('previous-select-${record.setId}'),
            onPressed: () => Navigator.pop(context, record),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, AppSize.touch),
            ),
            child: Text('이 기록 선택', style: AppType.action),
          ),
          const Divider(color: AppColors.hair),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(records.isEmpty ? '닫기' : '취소', style: AppType.action),
      ),
    ],
  ),
);

Future<bool> confirmPreviousOverwrite(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('입력한 값을 바꿀까요?', style: AppType.heading),
        content: Text(
          '현재 입력한 중량·단위·반복을 선택한 이전 기록으로 바꿔요. RIR·메모·수행일은 유지돼요.',
          style: AppType.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소', style: AppType.action),
          ),
          TextButton(
            key: const ValueKey('previous-overwrite-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text('입력 바꾸기', style: AppType.action),
          ),
        ],
      ),
    ) ??
    false;
