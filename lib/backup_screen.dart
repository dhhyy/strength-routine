import 'package:flutter/material.dart';
import 'app/training_controller.dart';
import 'data/backup_file_gateway.dart';
import 'data/training_backup.dart';
import 'domain/training_program.dart';
import 'flow_components.dart';
import 'tokens.dart';
import 'widgets.dart';

class BackupScreen extends StatefulWidget {
  final TrainingController controller;
  final BackupFileGateway? gateway;
  const BackupScreen({super.key, required this.controller, this.gateway});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  late final _service = TrainingBackupService(widget.controller);
  late final _gateway = widget.gateway ?? NativeBackupFileGateway();
  bool _busy = false;
  String? _message, _error;
  TrainingBackup? _candidate;
  int? _reviewRevision;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await action();
    } on FormatException catch (error) {
      if (mounted) {
        setState(
          () => _error = RegExp(r'[가-힣]').hasMatch(error.message)
              ? error.message
              : '파일 형식이나 운동 데이터 버전을 확인해 주세요. 이 앱에서 저장한 백업 파일이 필요해요.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = '파일을 처리하지 못했어요. 기록과 선택한 원본은 유지돼요. 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export({bool recovery = false}) => _run(() async {
    final text = recovery ? await _readRecovery() : _service.export();
    TrainingBackup.parse(text);
    final saved = await _gateway.save(
      text,
      'strength-${recovery ? 'recovery-' : ''}${isoDate(widget.controller.now())}.json',
    );
    if (mounted) {
      setState(
        () => _message = saved
            ? '파일 저장 요청을 마쳤어요. 선택한 위치에서 백업 파일을 확인해 주세요.'
            : '파일 저장을 취소했어요. 기록은 그대로예요.',
      );
    }
  });

  Future<void> _pick({bool recovery = false}) => _run(() async {
    final text = recovery ? await _readRecovery() : await _gateway.pick();
    if (!mounted) return;
    if (text == null) {
      setState(() => _message = '파일 선택을 취소했어요.');
      return;
    }
    final backup = TrainingBackup.parse(text);
    setState(() {
      _candidate = backup;
      _reviewRevision = widget.controller.revision;
    });
  });

  Future<String> _readRecovery() async {
    if (!await _service.recoveryFile.exists()) {
      throw const FormatException('아직 복구본이 없어요. 처음 기록을 복원하면 바로 이전 기록을 남겨요.');
    }
    return _service.recoveryFile.readAsString();
  }

  Future<void> _restore() async {
    final candidate = _candidate;
    final revision = _reviewRevision;
    if (candidate == null || revision == null || _busy) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bg,
        title: Text('운동 기록을 교체할까요?', style: AppType.heading),
        content: Text(
          '현재 운동 기록 전체를 검토한 파일로 바꿔요. 기존 기록은 복원 직전 복구본으로 남고 휴식 타이머는 종료돼요.',
          style: AppType.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('취소', style: AppType.action),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('기록 교체', style: AppType.action),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    await _run(() async {
      final success = await _service.restore(
        candidate,
        expectedRevision: revision,
      );
      if (!mounted) return;
      setState(() {
        if (success) {
          _candidate = null;
          _message = '운동 기록을 복원했어요. 새 기록과 계획을 확인해 주세요.';
        } else {
          _error = widget.controller.sessionActionError;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final ready = _service.ready && !_busy;
      final canRestore = _service.canRestore && !_busy;
      final candidate = _candidate;
      final stale =
          candidate != null && _reviewRevision != widget.controller.revision;
      return PopScope(
        canPop: !_busy,
        child: FlowPage(
          title: '운동 기록 백업',
          children: [
            Text('운동 기록을 파일로 보관하고 다시 불러와요.', style: AppType.heading),
            Text(
              '포함: 진행·보관 계획, 세트 기록·초안, 메모, 수행일, 마감 및 중량 조정 이력.',
              style: AppType.body,
            ),
            Text(
              '제외: 습관, 앱 설정, 관리자 작업, 휴식 타이머. 백업은 암호화되지 않은 파일이에요.',
              style: AppType.caption,
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              StatePanel(
                title: '처리하지 못했어요',
                message: _error!,
                icon: Icons.error_outline,
              ),
            if (_message != null) Text(_message!, style: AppType.body),
            if (widget.controller.loadError != null)
              Text(
                '현재 기기 기록을 읽지 못했어요. 백업을 가져오면 읽지 못한 원본 파일을 별도로 보존한 뒤 복원해요.',
                style: AppType.body,
              ),
            if (widget.controller.saveError != null)
              StatePanel(
                title: '아직 저장되지 않은 기록이 있어요',
                message: widget.controller.saveError!,
                action: PrimaryAction(
                  label: '기록 저장 다시 시도',
                  onPressed: _busy ? null : widget.controller.retrySave,
                ),
              ),
            if (widget.controller.loading || widget.controller.saving)
              Text('기록 저장을 마치면 백업할 수 있어요.', style: AppType.caption),
            PrimaryAction(
              label: '백업 파일 저장',
              onPressed: ready ? () => _export() : null,
            ),
            OutlinedButton(
              onPressed: canRestore ? () => _pick() : null,
              child: Text('백업 파일 가져오기', style: AppType.action),
            ),
            if (candidate != null) ...[
              GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('복원 전 확인', style: AppType.heading),
                    const SizedBox(height: AppSpace.x3),
                    Text('백업 생성 시각', style: AppType.caption),
                    Text(
                      '${isoDate(candidate.createdAt.toLocal())} '
                      '${candidate.createdAt.toLocal().hour.toString().padLeft(2, '0')}:'
                      '${candidate.createdAt.toLocal().minute.toString().padLeft(2, '0')}',
                      style: mono(
                        size: AppType.body.fontSize!,
                        color: AppColors.inkDim,
                      ),
                    ),
                    const SizedBox(height: AppSpace.x3),
                    Text('현재 기록', style: AppType.heading),
                    Text(
                      widget.controller.loadError != null
                          ? '기록을 읽지 못해 개수를 확인할 수 없어요.'
                          : _summary(widget.controller.state),
                      style: AppType.body,
                    ),
                    const SizedBox(height: AppSpace.x3),
                    Text('가져올 기록', style: AppType.heading),
                    Text(_summary(candidate.state), style: AppType.body),
                    const SizedBox(height: AppSpace.x3),
                    Text('두 기록을 합치지 않고 전체를 교체해요.', style: AppType.caption),
                  ],
                ),
              ),
              if (stale)
                Text(
                  '검토 후 기록이 바뀌었어요. 파일을 다시 가져와 검토해 주세요.',
                  style: AppType.body,
                ),
              PrimaryAction(
                label: '검토한 기록으로 복원',
                onPressed: canRestore && !stale ? _restore : null,
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() => _candidate = null),
                child: Text('복원 검토 취소', style: AppType.action),
              ),
            ],
            const Divider(color: AppColors.hair),
            Text('복원 직전 복구본', style: AppType.heading),
            Text(
              '복원할 때마다 바로 이전 운동 기록 한 개를 기기에 남겨요. 필요하면 파일로 보관하거나 다시 검토해 복원할 수 있어요.',
              style: AppType.caption,
            ),
            TextButton(
              onPressed: canRestore ? () => _pick(recovery: true) : null,
              child: Text('복구본 검토', style: AppType.action),
            ),
            TextButton(
              onPressed: ready ? () => _export(recovery: true) : null,
              child: Text('복구본 파일 저장', style: AppType.action),
            ),
          ],
        ),
      );
    },
  );

  String _summary(TrainingAppState state) {
    final completed = state.setActuals.values
        .where((a) => a.status == SetActualStatus.completed)
        .toList();
    final unknown = completed.where((a) => a.performedDate == null).length;
    return '계획 ${state.planHistory.length + (state.activePlan == null ? 0 : 1)}개 · '
        '완료 세트 ${completed.length}개 · 제외 ${state.setActuals.length - completed.length}개 · '
        '초안 ${state.setDrafts.length}개 · 수행일 미상 $unknown개';
  }
}
