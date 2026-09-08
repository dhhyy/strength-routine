import 'package:flutter/material.dart';

import '../domain/training_program.dart';
import '../flow_components.dart';
import '../prescription_widgets.dart';
import '../tokens.dart';
import '../widgets.dart';
import 'detailed_bulk_edit.dart';
import 'detailed_routine.dart';

class DetailedBulkScreen extends StatefulWidget {
  final DetailedRoutineDraft source;
  final int weekIndex, sessionIndex, exerciseIndex;
  const DetailedBulkScreen({
    super.key,
    required this.source,
    required this.weekIndex,
    required this.sessionIndex,
    required this.exerciseIndex,
  });
  @override
  State<DetailedBulkScreen> createState() => _DetailedBulkScreenState();
}

class _DetailedBulkScreenState extends State<DetailedBulkScreen> {
  DetailedBulkScope _scope = DetailedBulkScope.exercise;
  DetailedBulkField _field = DetailedBulkField.restSeconds;
  ProgramSetKind _kind = ProgramSetKind.work;
  String _value = '', _error = '';
  DetailedBulkPreview? _preview;
  void _review() {
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      final preview = previewDetailedBulkEdit(
        source: widget.source,
        weekIndex: widget.weekIndex,
        sessionIndex: widget.sessionIndex,
        exerciseIndex: widget.exerciseIndex,
        scope: _scope,
        field: _field,
        value: _value,
        kind: _kind,
      );
      setState(() {
        _preview = preview;
        _error = '';
      });
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: AppType.caption,
    filled: true,
    fillColor: AppColors.fill,
    contentPadding: const EdgeInsets.all(AppSpace.x4),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.ctrl),
      borderSide: const BorderSide(color: AppColors.hairStrong),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.ctrl),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final location =
        '${widget.weekIndex + 1}주차 · ${widget.sessionIndex + 1}회차 · ${widget.source.weeks[widget.weekIndex].sessions[widget.sessionIndex].exercises[widget.exerciseIndex].name}';
    return FlowPage(
      title: preview == null ? '세트 일괄 수정' : '일괄 수정 검토',
      children: [
        Text(location, style: AppType.heading),
        if (preview == null) ...[
          Text(
            '선택한 범위에서 한 필드만 변경합니다. 검토 후 적용하며 되돌리기로 복구할 수 있어요.',
            style: AppType.caption,
          ),
          DropdownButtonFormField<DetailedBulkScope>(
            key: const ValueKey('bulk-scope'),
            value: _scope,
            isExpanded: true,
            decoration: _decoration('수정 범위'),
            items: [
              for (final scope in DetailedBulkScope.values)
                DropdownMenuItem(
                  value: scope,
                  child: Text(bulkScopeLabel(scope), style: AppType.body),
                ),
            ],
            onChanged: (scope) => setState(() => _scope = scope!),
          ),
          DropdownButtonFormField<DetailedBulkField>(
            key: const ValueKey('bulk-field'),
            value: _field,
            isExpanded: true,
            decoration: _decoration('수정할 필드'),
            items: [
              for (final field in DetailedBulkField.values)
                DropdownMenuItem(
                  value: field,
                  child: Text(bulkFieldLabel(field), style: AppType.body),
                ),
            ],
            onChanged: (field) => setState(() {
              _field = field!;
              _error = '';
            }),
          ),
          if (_field == DetailedBulkField.kind)
            DropdownButtonFormField<ProgramSetKind>(
              key: const ValueKey('bulk-kind'),
              value: _kind,
              isExpanded: true,
              decoration: _decoration('새 종류'),
              items: [
                for (final kind in ProgramSetKind.values)
                  DropdownMenuItem(
                    value: kind,
                    child: Text(setKindLabel(kind), style: AppType.body),
                  ),
              ],
              onChanged: (kind) => setState(() => _kind = kind!),
            )
          else
            TextFormField(
              key: const ValueKey('bulk-value'),
              initialValue: _value,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: AppType.number,
              decoration: _decoration('새 값 · ${bulkFieldLabel(_field)}'),
              onChanged: (value) => _value = value,
            ),
          Text(switch (_field) {
            DetailedBulkField.repetitions => '1~100 사이의 정수. 지정된 상한을 넘을 수 없어요.',
            DetailedBulkField.repetitionsMax =>
              '하한 이상 100 이하. 빈 값은 고정 반복으로 돌아갑니다. AMRAP과 함께 지정할 수 없어요.',
            DetailedBulkField.rir => '0~10. 빈 값은 RIR 처방을 해제합니다.',
            DetailedBulkField.restSeconds => '0~3600초. 0은 휴식 없음, 빈 값은 미지정입니다.',
            DetailedBulkField.fixedKg =>
              '0보다 큰 중량. 대상의 중량 방식을 고정 kg로 바꾸고 기준 리프트를 해제합니다.',
            DetailedBulkField.kind => '작업·워밍업·드롭세트만 바꾸며 필수 여부와 중량은 유지합니다.',
          }, style: AppType.caption),
          if (_error.isNotEmpty)
            StatePanel(title: '일괄 수정 확인 필요', message: _error),
          PrimaryAction(label: '변경 내용 검토', onPressed: _review),
        ] else ...[
          Text(bulkScopeLabel(_scope), style: AppType.heading),
          Text(
            '대상 ${preview.targetCount}세트 · 변경 ${preview.changes.length}세트',
            key: const ValueKey('bulk-review-count'),
            style: AppType.heading,
          ),
          Text(
            '${bulkFieldLabel(_field)}만 바꿉니다. 카탈로그 확정 저장 전까지 편집 초안에만 적용됩니다.',
            style: AppType.caption,
          ),
          if (preview.changes.isEmpty)
            StatePanel(title: '변경할 값이 없어요', message: '대상 세트가 이미 같은 값입니다.'),
          if (preview.changes.isNotEmpty) ...[
            Text('새 값 · ${preview.changes.first.after}', style: AppType.body),
            GlassPanel(
              padding: const EdgeInsets.all(AppSpace.x3),
              child: ExpansionTile(
                key: const ValueKey('bulk-change-details'),
                initiallyExpanded: preview.changes.length <= 4,
                title: Text(
                  '세트별 변경 전후 ${preview.changes.length}개',
                  style: AppType.body,
                ),
                children: [
                  for (final change in preview.changes)
                    Padding(
                      padding: const EdgeInsets.all(AppSpace.x3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(change.location, style: AppType.body),
                          const SizedBox(height: AppSpace.x2),
                          Text(
                            '${change.before} → ${change.after}',
                            style: AppType.caption,
                          ),
                          const Divider(color: AppColors.hair),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          PrimaryAction(
            label: '초안에 일괄 적용',
            onPressed: preview.changes.isEmpty
                ? null
                : () => Navigator.pop(context, preview),
          ),
          OutlinedButton(
            onPressed: () => setState(() => _preview = null),
            child: Text('입력으로 돌아가기', style: AppType.action),
          ),
        ],
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('취소', style: AppType.action),
        ),
      ],
    );
  }
}
