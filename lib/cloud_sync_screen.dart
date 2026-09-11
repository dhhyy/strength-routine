import 'package:flutter/material.dart';

import 'app/cloud_snapshot_scope.dart';
import 'auth/auth_config.dart';
import 'auth/auth_scope.dart';
import 'flow_components.dart';
import 'tokens.dart';

/// 프로필에서 여는 서버 스냅샷 저장/불러오기.
class CloudSyncScreen extends StatelessWidget {
  const CloudSyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cloud = CloudSnapshotScope.maybeOf(context);
    final auth = AuthScope.maybeOf(context);
    if (cloud == null) {
      return const FlowPage(
        title: '서버 기록',
        children: [
          StatePanel(
            title: '서버 동기화가 준비되지 않았어요',
            message: '앱을 다시 실행해 주세요.',
            icon: Icons.cloud_off_outlined,
          ),
        ],
      );
    }
    return ListenableBuilder(
      listenable: Listenable.merge([
        cloud,
        if (auth != null) auth,
      ]),
      builder: (context, _) {
        final can = cloud.canSync;
        return FlowPage(
          title: '서버 기록',
          children: [
            StatePanel(
              title: can ? '서버에 복사해 두기' : '지금은 쓸 수 없어요',
              message: can
                  ? '기기의 운동 기록·working max를 서버에 한 장으로 저장하거나, 서버 복사본을 기기에 넣어요. 자동 동기화는 아직 아니에요.'
                  : cloud.blockedReason,
              icon: Icons.cloud_outlined,
            ),
            if (auth?.session != null)
              Text(
                '로그인: ${auth!.session!.displayName ?? auth.session!.userId}',
                style: AppType.caption,
              ),
            if (!AuthConfig.isConfigured)
              Text(
                '빌드에 SUPABASE_URL / SUPABASE_ANON_KEY가 필요합니다.',
                style: AppType.caption,
              ),
            if (cloud.message != null)
              Text(
                cloud.message!,
                style: AppType.body.copyWith(color: AppColors.good),
              ),
            if (cloud.error != null)
              Text(
                cloud.error!,
                style: AppType.body.copyWith(color: AppColors.warn),
              ),
            if (cloud.lastUploadedAt != null)
              Text(
                '최근 업로드: ${cloud.lastUploadedAt!.toLocal()}',
                style: AppType.caption,
              ),
            if (cloud.lastDownloadedAt != null)
              Text(
                '최근 다운로드: ${cloud.lastDownloadedAt!.toLocal()}',
                style: AppType.caption,
              ),
            if (cloud.busy) const LinearProgressIndicator(),
            PrimaryAction(
              label: '서버에 저장',
              busy: cloud.busy,
              onPressed: can && !cloud.busy ? cloud.upload : null,
            ),
            PrimaryAction(
              label: '서버에서 불러오기',
              busy: cloud.busy,
              onPressed: can && !cloud.busy
                  ? () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: AppColors.bgLift,
                          title: Text('불러올까요?', style: AppType.heading),
                          content: Text(
                            '기기의 현재 기록이 서버 복사본으로 바뀝니다. 필요할 때 먼저 「서버에 저장」으로 백업하세요.',
                            style: AppType.body,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text('취소', style: AppType.action),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text('불러오기', style: AppType.action),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) await cloud.download();
                    }
                  : null,
            ),
            Text(
              '테스트(우회) 로그인에서는 서버 저장이 꺼져 있어요.',
              style: AppType.caption,
            ),
          ],
        );
      },
    );
  }
}
