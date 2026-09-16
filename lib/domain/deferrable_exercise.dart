import 'recent_lift_record.dart';

/// 트레이너 확정: 이월은 메인 빅리프트 + 풀업·딥스만.
/// 보조는 템플릿에 있는 것만 수행하며, 자유 추가는 출시 후.
bool isDeferrableExercise({
  required String name,
  MainLift? lift,
}) {
  if (lift != null) return true;
  return deferrableKindForName(name) != null;
}

enum DeferrableLiftKind { squat, benchPress, deadlift, overheadPress, pullUp, dip }

DeferrableLiftKind? deferrableKindForName(String name) {
  final n = _normalize(name);
  if (n.isEmpty) return null;
  if (_isPullUp(n)) return DeferrableLiftKind.pullUp;
  if (_isDip(n)) return DeferrableLiftKind.dip;
  if (_isOverhead(n)) return DeferrableLiftKind.overheadPress;
  if (_isBench(n)) return DeferrableLiftKind.benchPress;
  if (_isDeadlift(n)) return DeferrableLiftKind.deadlift;
  if (_isSquat(n)) return DeferrableLiftKind.squat;
  return null;
}

String _normalize(String name) => name
    .toLowerCase()
    .replaceAll(RegExp(r'[\s_\-()]+'), '')
    .replaceAll('（', '')
    .replaceAll('）', '');

bool _isPullUp(String n) =>
    n.contains('풀업') ||
    n.contains('턱걸이') ||
    n.contains('pullup') ||
    n.contains('pullups') ||
    n.contains('chinup');

bool _isDip(String n) =>
    n.contains('딥스') ||
    n == '딥' ||
    n.contains('chestdip') ||
    n.endsWith('dip') ||
    n.endsWith('dips');

bool _isOverhead(String n) =>
    n.contains('오버헤드') ||
    n.contains('overheadpress') ||
    n.contains('ohp') ||
    n.contains('밀리터리프레스') ||
    n.contains('militarypress');

bool _isBench(String n) {
  if (n.contains('체스트프레스') || n.contains('chestpress')) return false;
  return n.contains('벤치프레스') ||
      n.contains('벤치프레스') ||
      n.contains('benchpress');
}

bool _isDeadlift(String n) {
  if (n.contains('루마니안') ||
      n.contains('romanian') ||
      n.contains('rdl') ||
      n.contains('스티프') ||
      n.contains('stiff')) {
    return false;
  }
  return n.contains('데드리프트') || n.contains('deadlift');
}

bool _isSquat(String n) => n.contains('스쿼트') || n.contains('squat');
