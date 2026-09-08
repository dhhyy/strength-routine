import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'domain/exercise_guides.dart';
import 'flow_components.dart';
import 'tokens.dart';
import 'widgets.dart';

typedef GuideSourceOpener = Future<bool> Function(Uri uri);
Future<bool> _openGuideSource(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Plain instructions remain on device; only an explicit source action opens a URL.
class ExerciseGuideScreen extends StatefulWidget {
  final ExerciseGuide guide;
  final GuideSourceOpener? openSource;
  const ExerciseGuideScreen({super.key, required this.guide, this.openSource});
  @override
  State<ExerciseGuideScreen> createState() => _ExerciseGuideScreenState();
}

class _ExerciseGuideScreenState extends State<ExerciseGuideScreen> {
  bool _opening = false;
  String? _error;
  Future<void> _open() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final uri = Uri.parse(widget.guide.sourceUrl);
      if (uri.scheme != 'https' ||
          uri.host.isEmpty ||
          !await (widget.openSource ?? _openGuideSource)(uri)) {
        throw const FormatException('Source unavailable');
      }
    } catch (_) {
      if (mounted)
        setState(
          () => _error = '출처를 열지 못했어요. 출처 열기를 다시 시도해 주세요. 안내 본문은 계속 읽을 수 있어요.',
        );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final guide = widget.guide;
    return FlowPage(
      title: '운동 가이드',
      children: [
        GuideText(guide.name, style: AppType.heading),
        Text('장비 · ${guide.equipment}', style: AppType.caption),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('시작 자세', style: AppType.heading),
              const SizedBox(height: AppSpace.x2),
              GuideText(guide.setup),
              const SizedBox(height: AppSpace.x6),
              Text('움직임', style: AppType.heading),
              const SizedBox(height: AppSpace.x2),
              GuideText(guide.movement),
              const SizedBox(height: AppSpace.x6),
              Text('확인할 점', style: AppType.heading),
              const SizedBox(height: AppSpace.x2),
              GuideText(guide.check),
            ],
          ),
        ),
        Text(
          '본문은 오프라인으로 읽을 수 있어요. 목표 세트·중량은 선택한 프로그램을 확인해 주세요.',
          style: AppType.caption,
        ),
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('동작 안내 출처', style: AppType.heading),
              const SizedBox(height: AppSpace.x2),
              GuideText(guide.sourceTitle),
              const SizedBox(height: AppSpace.x2),
              Text('원문은 외부 브라우저에서 열려요.', style: AppType.caption),
              const SizedBox(height: AppSpace.x3),
              PrimaryAction(
                label: _error == null ? '출처 원문 열기' : '출처 다시 열기',
                busy: _opening,
                onPressed: _open,
              ),
            ],
          ),
        ),
        if (_error != null)
          StatePanel(title: '출처 연결 실패', message: _error!, icon: Icons.link_off),
      ],
    );
  }
}

class ExerciseGuideLink extends StatelessWidget {
  final String exerciseName;
  const ExerciseGuideLink({super.key, required this.exerciseName});
  @override
  Widget build(BuildContext context) {
    final guide = guideForExercise(exerciseName);
    if (guide == null)
      return Text('이 종목은 등록된 가이드가 없어요.', style: AppType.caption);
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(AppSize.touch, AppSize.touch),
        ),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ExerciseGuideScreen(guide: guide),
          ),
        ),
        icon: const Icon(Icons.menu_book_outlined, size: AppSize.icon),
        label: Text('운동 가이드 보기', style: AppType.action),
      ),
    );
  }
}

class ExerciseGuidesScreen extends StatefulWidget {
  const ExerciseGuidesScreen({super.key});
  @override
  State<ExerciseGuidesScreen> createState() => _ExerciseGuidesScreenState();
}

class _ExerciseGuidesScreenState extends State<ExerciseGuidesScreen> {
  final _query = TextEditingController();
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = searchExerciseGuides(_query.text);
    return FlowPage(
      title: '운동·용어 가이드',
      children: [
        Text('기본 프로그램의 동작 설명을 찾아보세요.', style: AppType.body),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(AppSize.touch, AppSize.touch),
          ),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const TrainingGlossaryScreen(),
            ),
          ),
          icon: const Icon(Icons.help_outline, size: AppSize.icon),
          label: Text('운동 용어 읽기', style: AppType.action),
        ),
        ConsoleField(
          key: const ValueKey('guide-search-query'),
          controller: _query,
          label: '종목·장비·별칭 검색',
          numeric: false,
          onChanged: (_) => setState(() {}),
        ),
        if (_query.text.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(_query.clear),
              icon: const Icon(Icons.clear, size: AppSize.icon),
              label: Text('검색어 지우기', style: AppType.action),
            ),
          ),
        if (results.isEmpty)
          const StatePanel(
            title: '가이드 검색 결과가 없어요',
            message: '운동 이름이나 장비를 확인해 주세요. 아직 등록하지 않은 종목도 있어요.',
            icon: Icons.search_off,
          ),
        if (results.isNotEmpty)
          Text('운동 가이드 ${results.length}개', style: AppType.caption),
        for (final guide in results)
          GlassPanel(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: GuideText(guide.name, style: AppType.heading),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: AppSpace.x2),
                child: Text(guide.equipment, style: AppType.caption),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                size: AppSize.icon,
                color: AppColors.accent,
              ),
              onTap: () {
                FocusScope.of(context).unfocus();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ExerciseGuideScreen(guide: guide),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class TrainingGlossaryScreen extends StatelessWidget {
  const TrainingGlossaryScreen({super.key});
  @override
  Widget build(BuildContext context) => FlowPage(
    title: '운동 용어',
    children: [
      for (final item in trainingGlossary)
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GuideText(item.term, style: AppType.heading),
              const SizedBox(height: AppSpace.x2),
              GuideText(item.description),
            ],
          ),
        ),
    ],
  );
}

/// Korean glyphs use the KR family; Latin terms and numeric values use mono.
class GuideText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  const GuideText(this.text, {super.key, this.style});
  @override
  Widget build(BuildContext context) {
    final base = style ?? AppType.body;
    final spans = <InlineSpan>[];
    var offset = 0;
    for (final match in RegExp(
      r'[A-Za-z0-9][A-Za-z0-9 &·.-]*',
    ).allMatches(text)) {
      if (match.start > offset)
        spans.add(TextSpan(text: text.substring(offset, match.start)));
      spans.add(
        TextSpan(
          text: match.group(0),
          style: mono().copyWith(
            fontSize: base.fontSize,
            fontWeight: base.fontWeight,
            color: base.color,
          ),
        ),
      );
      offset = match.end;
    }
    if (offset < text.length) spans.add(TextSpan(text: text.substring(offset)));
    return Text.rich(TextSpan(style: base, children: spans));
  }
}
