import 'package:flutter/material.dart';
import 'tokens.dart';
import 'widgets.dart';
import 'components.dart';

/// 운동 검색 — 검색 + 부위 필터 + 리스트.
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: '운동 검색',
      children: [
        GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          child: Row(
            children: [
              const Icon(Icons.search, size: 17, color: AppColors.muted),
              const SizedBox(width: 10),
              Text('운동명 · 부위 검색', style: kr(size: 14, color: AppColors.muted)),
            ],
          ),
        ),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: const [
            PillChip('전체', selected: true),
            PillChip('가슴'),
            PillChip('등'),
            PillChip('어깨'),
            PillChip('하체'),
            PillChip('팔'),
            PillChip('코어'),
          ],
        ),
        GlassPanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: const [
              ExerciseTile(name: '백스쿼트', part: '하체 · 대퇴사두'),
              ExerciseTile(name: '벤치프레스', part: '가슴 · 삼두', divider: true),
              ExerciseTile(name: '데드리프트', part: '하체 · 등 · 후면사슬', divider: true),
              ExerciseTile(name: '풀업', part: '등 · 이두', divider: true),
              ExerciseTile(name: '오버헤드프레스', part: '어깨 · 삼두', divider: true),
              ExerciseTile(name: '바벨 로우', part: '등 · 광배', divider: true),
            ],
          ),
        ),
      ],
    );
  }
}
