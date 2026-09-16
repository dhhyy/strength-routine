/// 공개 계약 버전. 정책 숫자를 바꾸면 새 id를 낸다.
const kEngineVersion = EngineVersion(
  id: 'engine-v1',
  policyIds: ['e1rm-epley-v1', 'd5-3x1-5pct-v1'],
);

final class EngineVersion {
  final String id;
  final List<String> policyIds;
  const EngineVersion({required this.id, required this.policyIds});
}
