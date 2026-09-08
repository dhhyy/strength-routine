/// Authored offline summaries, reviewed against the linked original sources on
/// 2026-09-08. These aliases are for navigation, never workout record identity.
final class ExerciseGuide {
  final String id,
      name,
      equipment,
      setup,
      movement,
      check,
      sourceTitle,
      sourceUrl;
  final List<String> aliases;
  const ExerciseGuide({
    required this.id,
    required this.name,
    required this.equipment,
    required this.setup,
    required this.movement,
    required this.check,
    required this.sourceTitle,
    required this.sourceUrl,
    this.aliases = const [],
  });
}

const exerciseGuides = <ExerciseGuide>[
  ExerciseGuide(
    id: 'goblet-squat',
    name: '고블렛 스쿼트',
    equipment: '덤벨',
    aliases: ['덤벨 고블렛 스쿼트', 'Goblet Squat'],
    setup: '덤벨 하나를 세워 가슴 앞에서 양손으로 잡고 발을 어깨너비로 벌려요.',
    movement: '팔꿈치를 몸 가까이 두고 엉덩이와 무릎을 굽혀 앉은 뒤 발로 바닥을 밀며 일어나요.',
    check: '등과 발의 지지가 유지되는 범위에서 움직여요. 덤벨을 앞으로 멀리 보내지 않아요.',
    sourceTitle: 'ACE · Goblet Squat',
    sourceUrl:
        'https://www.acefitness.org/resources/everyone/exercise-library/362/goblet-squat/',
  ),
  ExerciseGuide(
    id: 'dumbbell-squat',
    name: '덤벨 스쿼트',
    equipment: '덤벨',
    aliases: ['Dumbbell Squat'],
    setup: '양손에 덤벨을 들어 몸 옆에 두고 발을 어깨너비로 벌려요.',
    movement: '복부에 힘을 주고 엉덩이와 무릎을 굽혀 앉았다가 발로 바닥을 밀어 일어나요.',
    check: '무릎은 발끝 방향을 따라가요. 상체가 무너지지 않는 깊이를 사용해요.',
    sourceTitle: 'Muscle & Strength · Dumbbell Squat',
    sourceUrl:
        'https://www.muscleandstrength.com/exercises/dumbbell-squat.html',
  ),
  ExerciseGuide(
    id: 'barbell-back-squat',
    name: '바벨 백스쿼트',
    equipment: '바벨·랙',
    aliases: ['바벨 백 스쿼트', 'Barbell Back Squat'],
    setup: '랙의 바를 어깨보다 약간 낮게 맞추고 목이 아닌 등 위에 받쳐 양손으로 잡아요.',
    movement: '바를 들어 뒤로 이동해 발을 고정하고 엉덩이와 무릎을 굽혀 앉은 뒤 일어나요.',
    check: '바와 몸통을 안정적으로 지지해요. 랙 안전장치와 보조자의 도움을 준비해요.',
    sourceTitle: 'ACE · Back Squat',
    sourceUrl:
        'https://www.acefitness.org/resources/everyone/exercise-library/11/back-squat/',
  ),
  ExerciseGuide(
    id: 'leg-press',
    name: '레그 프레스',
    equipment: '레그 프레스 머신',
    aliases: ['레그프레스', 'Leg Press'],
    setup: '등과 머리를 등받이에 대고 발판에 양발을 놓아요. 기구 설명대로 좌석과 안전장치를 맞춰요.',
    movement: '발판을 밀어 다리를 편 뒤 무릎을 굽히며 천천히 돌아와요.',
    check: '무릎을 튕겨 잠그지 않아요. 골반과 등이 들리지 않는 범위에서 내려요.',
    sourceTitle: 'NASM · Leg Press',
    sourceUrl:
        'https://www.nasm.org/resource-center/exercise-library/leg-press',
  ),
  ExerciseGuide(
    id: 'dumbbell-rdl',
    name: '덤벨 루마니안 데드리프트',
    equipment: '덤벨',
    aliases: ['Dumbbell Romanian Deadlift', '덤벨 RDL'],
    setup: '덤벨을 양손에 들고 발을 골반너비로 벌려요. 무릎은 조금 굽혀요.',
    movement: '엉덩이를 뒤로 보내며 덤벨을 다리 가까이 내리고 엉덩이를 앞으로 가져와 일어나요.',
    check: '내려갈수록 무릎을 계속 굽혀 스쿼트로 바꾸지 않아요. 등을 유지할 수 있는 범위까지만 내려요.',
    sourceTitle: 'NASM · Dumbbell Romanian Deadlift',
    sourceUrl:
        'https://www.nasm.org/resource-center/exercise-library/dumbbell-romanian-deadlift',
  ),
  ExerciseGuide(
    id: 'barbell-rdl',
    name: '바벨 루마니안 데드리프트',
    equipment: '바벨',
    aliases: ['Barbell Romanian Deadlift', '바벨 RDL'],
    setup: '바벨을 허벅지 앞에 들고 서서 발을 골반너비로 벌리고 무릎을 조금 굽혀요.',
    movement: '바를 다리 가까이 유지하며 엉덩이를 뒤로 보내 내려갔다가 다시 서요.',
    check: '바를 바닥에 닿게 하는 것이 목표가 아니에요. 허리를 둥글게 말거나 뒤로 젖히지 않아요.',
    sourceTitle: 'ACE · Romanian Deadlift',
    sourceUrl:
        'https://www.acefitness.org/continuing-education/certified/may-2025/8865/the-ace-do-it-better-series-the-romanian-deadlift/',
  ),
  ExerciseGuide(
    id: 'seated-leg-curl',
    name: '시티드 레그 컬',
    equipment: '시티드 레그 컬 머신',
    aliases: ['시티드 레그컬', 'Seated Leg Curl'],
    setup: '등을 받치고 허벅지 고정 패드와 발목 위쪽의 움직이는 패드를 기구 설명에 맞춰 조절해요.',
    movement: '몸통을 유지하며 무릎을 굽혀 발뒤꿈치를 아래와 뒤로 당긴 뒤 천천히 펴요.',
    check: '엉덩이가 들리거나 좌우로 돌아가지 않게 해요. 패드를 반동으로 움직이지 않아요.',
    sourceTitle: 'ACE · Hamstrings study exercise instructions',
    sourceUrl:
        'https://www.acefitness.org/continuing-education/certified/february-2018/6896/ace-sponsored-research-what-is-the-best-exercise-for-the-hamstrings/',
  ),
  ExerciseGuide(
    id: 'dumbbell-glute-bridge',
    name: '덤벨 글루트 브리지',
    equipment: '덤벨·바닥',
    aliases: ['덤벨 글루트 브릿지', 'Dumbbell Glute Bridge'],
    setup: '바닥에 누워 무릎을 굽히고 발을 놓아요. 덤벨을 골반 위에 안정적으로 올려 양손으로 고정해요.',
    movement: '발을 누르며 엉덩이를 들어 무릎부터 어깨까지 이어지는 선을 만들고 천천히 내려요.',
    check: '허리를 과하게 젖혀 높이를 만들지 않아요. 덤벨이 굴러가지 않게 계속 잡아요.',
    sourceTitle: 'NASM · Squat alternatives / Floor bridges',
    sourceUrl: 'https://www.nasm.org/resource-center/blog/squat-alternatives',
  ),
  ExerciseGuide(
    id: 'dumbbell-standing-calf',
    name: '덤벨 스탠딩 카프 레이즈',
    equipment: '덤벨',
    aliases: ['Dumbbell Standing Calf Raise'],
    setup: '덤벨을 몸 옆에 들고 발을 골반너비로 벌려 평평한 바닥에 서요.',
    movement: '발 앞부분으로 바닥을 눌러 뒤꿈치를 올린 뒤 천천히 바닥으로 내려요.',
    check: '무릎을 굽혔다 펴는 반동을 사용하지 않아요. 몸이 앞뒤로 흔들리지 않게 해요.',
    sourceTitle: 'REP Fitness · Dumbbell calf raises',
    sourceUrl: 'https://repfitness.com/blogs/training/dumbbell-calf-raises',
  ),
  ExerciseGuide(
    id: 'dumbbell-bench',
    name: '덤벨 벤치프레스',
    equipment: '덤벨·평벤치',
    aliases: ['덤벨 벤치 프레스', 'Dumbbell Bench Press'],
    setup: '평벤치에 등을 대고 누워 양발을 지지해요. 양손 덤벨을 가슴 위에서 잡아요.',
    movement: '덤벨을 가슴 양옆으로 천천히 내렸다가 위로 밀어 올려요.',
    check: '손목을 전완과 나란히 유지해요. 머리·등·엉덩이와 발의 지지를 유지해요.',
    sourceTitle: 'ACE · Dumbbell chest press',
    sourceUrl:
        'https://www.acefitness.org/resources/everyone/exercise-library/19/chest-press/',
  ),
  ExerciseGuide(
    id: 'dumbbell-incline',
    name: '덤벨 인클라인 프레스',
    equipment: '덤벨·인클라인 벤치',
    aliases: ['Dumbbell Incline Press'],
    setup: '각도를 고정한 인클라인 벤치에 등을 대고 누워 양발을 바닥에 놓아요.',
    movement: '덤벨을 윗가슴 양옆으로 내렸다가 위로 함께 밀어 올려요.',
    check: '팔꿈치 위에 손목이 놓이게 해요. 덤벨을 튕기거나 허리를 크게 젖히지 않아요.',
    sourceTitle: 'ACE · Incline chest press',
    sourceUrl:
        'https://www.acefitness.org/resources/everyone/exercise-library/25/incline-chest-press/',
  ),
  ExerciseGuide(
    id: 'dumbbell-floor',
    name: '덤벨 플로어 프레스',
    equipment: '덤벨·바닥',
    aliases: ['Dumbbell Floor Press'],
    setup: '덤벨을 몸 가까이 잡고 바닥에 누워 무릎을 굽혀 발을 지지해요.',
    movement: '덤벨을 밀어 올린 뒤 양 팔꿈치가 바닥에 닿을 때까지 천천히 내려요.',
    check: '팔꿈치를 바닥에 튕기지 않아요. 양 덤벨을 위에서 부딪치지 않아요.',
    sourceTitle: 'Muscle & Strength · Dumbbell floor press',
    sourceUrl:
        'https://www.muscleandstrength.com/exercises/dumbbell-floor-press.html',
  ),
  ExerciseGuide(
    id: 'barbell-bench',
    name: '바벨 벤치프레스',
    equipment: '바벨·벤치·랙',
    aliases: ['바벨 벤치 프레스', 'Barbell Bench Press'],
    setup: '벤치에 누워 발을 바닥에 두고 바를 어깨너비보다 조금 넓게 잡아요.',
    movement: '바를 랙에서 꺼내 가슴 쪽으로 천천히 내린 뒤 위로 밀어요.',
    check: '엉덩이와 발의 지지를 유지해요. 랙 안전장치와 보조자의 도움을 준비해요.',
    sourceTitle: 'ACE · Barbell chest press',
    sourceUrl:
        'https://www.acefitness.org/resources/everyone/exercise-library/5/chest-press/',
  ),
  ExerciseGuide(
    id: 'machine-chest',
    name: '머신 체스트 프레스',
    equipment: '체스트 프레스 머신',
    aliases: ['Machine Chest Press'],
    setup: '손잡이가 가슴 높이에 오도록 좌석을 맞추고 등과 발을 받쳐요.',
    movement: '손잡이를 앞으로 밀어 팔꿈치를 편 뒤 천천히 처음 위치로 돌아와요.',
    check: '손목이 꺾이거나 어깨가 등받이에서 크게 들리지 않게 해요. 기구의 시작 위치를 확인해요.',
    sourceTitle: 'ACE · Seated chest press',
    sourceUrl:
        'https://www.acefitness.org/resources/everyone/exercise-library/188/seated-chest-press/',
  ),
  ExerciseGuide(
    id: 'dumbbell-shoulder',
    name: '덤벨 숄더 프레스',
    equipment: '덤벨·등받이 벤치',
    aliases: ['Dumbbell Shoulder Press'],
    setup: '이 안내는 앉은 자세 기준이에요. 등과 발을 받치고 덤벨을 어깨 높이에 들어요.',
    movement: '덤벨을 머리 위로 함께 밀어 올렸다가 어깨 높이로 천천히 내려요.',
    check: '손목을 꺾거나 허리를 과하게 젖히지 않아요. 몸통을 안정적으로 유지해요.',
    sourceTitle: 'ACE · Seated overhead press',
    sourceUrl:
        'https://www.acefitness.org/resources/everyone/exercise-library/45/seated-overhead-press/',
  ),
  ExerciseGuide(
    id: 'barbell-overhead',
    name: '바벨 오버헤드프레스',
    equipment: '바벨·랙',
    aliases: ['바벨 오버헤드 프레스', 'Barbell Overhead Press'],
    setup: '바를 어깨 앞에서 잡고 발을 어깨너비로 벌려 서요.',
    movement: '복부와 엉덩이에 힘을 주고 바를 머리 위로 밀었다가 가슴 위쪽으로 천천히 내려요.',
    check: '다리 반동으로 밀어 올리지 않아요. 바를 피하려고 몸을 과하게 뒤로 젖히지 않아요.',
    sourceTitle: 'Muscle & Strength · Military press',
    sourceUrl:
        'https://www.muscleandstrength.com/exercises/military-press.html',
  ),
  ExerciseGuide(
    id: 'dumbbell-lateral',
    name: '덤벨 레터럴 레이즈',
    equipment: '덤벨',
    aliases: ['덤벨 레터럴레이즈', 'Dumbbell Lateral Raise'],
    setup: '덤벨을 몸 옆에 들고 서서 팔꿈치를 살짝 굽혀요.',
    movement: '양팔을 옆으로 천천히 들어 어깨 높이까지 올렸다가 내려요.',
    check: '몸통 반동을 쓰지 않아요. 손목을 과하게 꺾거나 어깨를 으쓱하지 않아요.',
    sourceTitle: 'ACE · Lateral raise',
    sourceUrl:
        'https://www.acefitness.org/resources/everyone/exercise-library/26/lateral-raise/',
  ),
  ExerciseGuide(
    id: 'lat-pulldown',
    name: '랫 풀다운',
    equipment: '랫 풀다운 머신',
    aliases: ['랫풀다운', 'Lat Pulldown'],
    setup: '허벅지 패드를 맞추고 앉아 머리 위 바를 잡아요. 몸통을 안정적으로 세워요.',
    movement: '팔꿈치를 아래로 보내 바를 가슴 위쪽으로 당긴 뒤 천천히 위로 돌려보내요.',
    check: '목 뒤로 당기지 않아요. 몸을 크게 뒤로 흔들어 중량을 내리지 않아요.',
    sourceTitle: 'ACE · Seated lat pulldown',
    sourceUrl:
        'https://www.acefitness.org/resources/everyone/exercise-library/158/seated-lat-pulldown/',
  ),
  ExerciseGuide(
    id: 'seated-cable-row',
    name: '시티드 케이블 로우',
    equipment: '케이블 로우 머신',
    aliases: ['Seated Cable Row'],
    setup: '발을 지지하고 무릎을 조금 굽혀 앉은 뒤 손잡이를 잡고 몸통을 세워요.',
    movement: '손잡이를 복부 쪽으로 당긴 뒤 팔을 천천히 펴며 돌아가요.',
    check: '몸통을 앞뒤로 흔들어 당기지 않아요. 등을 둥글게 말지 않아요.',
    sourceTitle: 'Muscle & Strength · Seated cable row',
    sourceUrl: 'https://www.muscleandstrength.com/exercises/seated-row.html',
  ),
  ExerciseGuide(
    id: 'dumbbell-bent-row',
    name: '덤벨 벤트오버 로우',
    equipment: '덤벨',
    aliases: ['Dumbbell Bent Over Row'],
    setup: '덤벨을 양손에 잡고 엉덩이를 뒤로 보내 몸통을 앞으로 기울여요.',
    movement: '몸통 각도를 유지하며 팔꿈치를 뒤로 당겼다가 덤벨을 천천히 내려요.',
    check: '머리만 앞으로 내밀거나 몸통 반동으로 당기지 않아요.',
    sourceTitle: 'Muscle & Strength · Bent over dumbbell row',
    sourceUrl:
        'https://www.muscleandstrength.com/exercises/bent-over-dumbbell-row.html',
  ),
  ExerciseGuide(
    id: 'dumbbell-supported-row',
    name: '덤벨 체스트 서포티드 로우',
    equipment: '덤벨·인클라인 벤치',
    aliases: ['Chest Supported Dumbbell Row'],
    setup: '각도를 고정한 벤치에 가슴을 대고 엎드려 양손에 덤벨을 잡아요.',
    movement: '팔꿈치를 뒤로 보내 덤벨을 몸통 쪽으로 당겼다가 천천히 내려요.',
    check: '가슴을 벤치에서 크게 떼어 반동을 만들지 않아요. 목을 앞으로 내밀지 않아요.',
    sourceTitle: 'Muscle & Strength · Chest supported dumbbell row',
    sourceUrl:
        'https://www.muscleandstrength.com/exercises/chest-supported-dumbbell-row',
  ),
  ExerciseGuide(
    id: 'dumbbell-curl',
    name: '덤벨 바이셉스 컬',
    equipment: '덤벨·등받이 벤치',
    aliases: ['덤벨 바이셉스컬', 'Dumbbell Biceps Curl'],
    setup: '이 안내는 앉은 자세 기준이에요. 등을 받치고 덤벨을 몸 옆에 들어 손바닥이 앞을 향하게 해요.',
    movement: '팔꿈치를 굽혀 덤벨을 올렸다가 천천히 내려요.',
    check: '몸을 흔들거나 손목을 꺾지 않아요. 팔꿈치를 앞으로 밀어 올리지 않아요.',
    sourceTitle: 'ACE · Seated biceps curl',
    sourceUrl:
        'https://www.acefitness.org/resources/everyone/exercise-library/44/seated-biceps-curl/',
  ),
  ExerciseGuide(
    id: 'cable-triceps',
    name: '케이블 트라이셉스 프레스다운',
    equipment: '상단 케이블·바 손잡이',
    aliases: ['Cable Triceps Pressdown', '케이블 트라이셉스 푸시다운'],
    setup: '이 안내는 바 손잡이 기준이에요. 케이블을 마주 보고 서서 바를 잡고 팔꿈치를 몸 옆에 둬요.',
    movement: '팔꿈치를 펴며 바를 아래로 누른 뒤 천천히 처음 위치로 올려요.',
    check: '몸을 흔들거나 허리를 크게 굽혀 중량을 누르지 않아요.',
    sourceTitle: 'StrengthLog · Tricep pushdown with bar',
    sourceUrl: 'https://www.strengthlog.com/tricep-pushdown-with-bar/',
  ),
  ExerciseGuide(
    id: 'bodyweight-crunch',
    name: '크런치 (맨몸)',
    equipment: '바닥',
    aliases: ['맨몸 크런치', 'Bodyweight Crunch'],
    setup: '바닥에 등을 대고 누워 무릎을 굽히고 발을 놓아요.',
    movement: '복부를 수축해 어깨와 등 위쪽을 바닥에서 살짝 들어 올린 뒤 천천히 내려요.',
    check: '목을 손으로 잡아당기지 않아요. 상체를 완전히 세우는 윗몸일으키기와 구분해요.',
    sourceTitle: 'StrengthLog · Crunch',
    sourceUrl: 'https://www.strengthlog.com/crunch/',
  ),
];

ExerciseGuide? guideForExercise(String name) {
  final exact = name.trim().toLowerCase();
  for (final guide in exerciseGuides) {
    if ([
      guide.name,
      ...guide.aliases,
    ].any((alias) => alias.toLowerCase() == exact)) {
      return guide;
    }
  }
  return null;
}

List<ExerciseGuide> searchExerciseGuides(String query) {
  final term = query.trim().toLowerCase();
  return List.unmodifiable(
    exerciseGuides.where(
      (guide) => [
        guide.name,
        guide.equipment,
        ...guide.aliases,
      ].any((text) => text.toLowerCase().contains(term)),
    ),
  );
}

const trainingGlossary = <({String term, String description})>[
  (term: '세트', description: '쉬지 않고 이어서 수행하는 반복의 묶음이에요. 앱의 한 기록 행에 해당해요.'),
  (term: '반복', description: '동작을 수행한 횟수예요. 목표와 별도로 실제로 한 횟수를 기록해요.'),
  (
    term: '반복 범위',
    description: '최소·최대 목표 횟수예요. 실제 반복은 직접 기록하며 감량 비교는 목표 하한을 사용해요.',
  ),
  (
    term: 'RIR · 남긴 반복',
    description: '같은 자세로 더 할 수 있었다고 판단한 횟수예요. 모르면 비워 두며 앱이 자동으로 추정하지 않아요.',
  ),
  (
    term: 'AMRAP',
    description:
        '관리자가 지정한 노력 수준과 자세를 유지하며 가능한 반복을 수행하는 세트예요. 앱의 기준 반복은 최소 합격선이 아니며 실제 반복을 직접 적어요.',
  ),
  (
    term: '템포',
    description:
        '내림·아래 멈춤·올림·위 멈춤의 네 단계 시간이에요. 올림의 X는 빠르게 올리라는 표시이며 앱이 실제 시간을 측정하지 않아요.',
  ),
  (
    term: '슈퍼세트',
    description:
        '묶인 운동을 세트별로 번갈아 수행해요. 앱은 첫 운동 1세트 → 다음 운동 1세트 순서로 안내하며 각 세트의 휴식 처방을 유지해요.',
  ),
  (
    term: '워밍업 세트',
    description:
        '본 운동을 준비하도록 관리자가 작성한 세트예요. 기록은 남지만 고정 작업 세트의 감량 비교와 조정 대상에서는 제외해요.',
  ),
  (
    term: '드롭세트',
    description:
        '중량을 줄여 이어가는 세트를 관리자가 각각 작성해요. 앱이 중량을 자동으로 내리거나 추가 세트를 만들지는 않아요.',
  ),
];
