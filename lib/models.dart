// 엔진(순수 함수)이 만들어내는 값의 형태.
// 위젯은 이 데이터를 '렌더'만 한다 — 로직과 화면의 분리.

enum SetStatus { done, now, pending }

enum ExRole { mainVolume, techMaintain, accessory }

class SetEntry {
  final SetStatus status;
  const SetEntry(this.status);
}

class Exercise {
  final String name;
  final ExRole role;
  final bool hero; // true면 큰 히어로 카드, false면 접힌 행
  final String? weight; // 히어로: '100'
  final String? unit; // 히어로: 'kg'
  final String subtitle; // 히어로: '목표 5회 · RIR 2' / 행: '120kg · 2세트 × 3회'
  final String? ruleNote; // 엔진 규칙 이유 (자동 하향 등)
  final List<SetEntry> sets;
  const Exercise({
    required this.name,
    required this.role,
    this.hero = false,
    this.weight,
    this.unit,
    required this.subtitle,
    this.ruleNote,
    required this.sets,
  });

  int get done => sets.where((s) => s.status == SetStatus.done).length;
  int get total => sets.length;
  int get current => done + 1;
}

class Session {
  final String dateLabel, dateSub, phaseLabel, focus, quote, quoteBy;
  final double neuralLoad; // 0..1 (회복 여력)
  final int weekVolDone, weekVolTarget;
  final List<Exercise> exercises;
  const Session({
    required this.dateLabel,
    required this.dateSub,
    required this.phaseLabel,
    required this.focus,
    required this.quote,
    required this.quoteBy,
    required this.neuralLoad,
    required this.weekVolDone,
    required this.weekVolTarget,
    required this.exercises,
  });
  double get weekFrac => weekVolDone / weekVolTarget;
}

/// 목업과 동일한 샘플 세션 (실제로는 엔진이 생성).
const demoSession = Session(
  dateLabel: '오늘',
  dateSub: '09.05 금',
  phaseLabel: '블록 1 · 2주차 · 볼륨',
  focus: '하체 · 스쿼트',
  quote: '천천히 가도 괜찮다. 멈추지만 않으면.',
  quoteBy: '공자',
  neuralLoad: 0.62,
  weekVolDone: 14,
  weekVolTarget: 18,
  exercises: [
    Exercise(
      name: '백스쿼트',
      role: ExRole.mainVolume,
      hero: true,
      weight: '100',
      unit: 'kg',
      subtitle: '목표 5회 · RIR 2',
      sets: [
        SetEntry(SetStatus.done),
        SetEntry(SetStatus.done),
        SetEntry(SetStatus.done),
        SetEntry(SetStatus.now),
      ],
    ),
    Exercise(
      name: '데드리프트',
      role: ExRole.techMaintain,
      subtitle: '120kg · 2세트 × 3회',
      ruleNote: '스쿼트가 메인이라 가볍게',
      sets: [SetEntry(SetStatus.pending), SetEntry(SetStatus.pending)],
    ),
    Exercise(
      name: '레그 프레스',
      role: ExRole.accessory,
      subtitle: '3세트 × 10회 · RIR 2',
      sets: [
        SetEntry(SetStatus.pending),
        SetEntry(SetStatus.pending),
        SetEntry(SetStatus.pending),
      ],
    ),
  ],
);
