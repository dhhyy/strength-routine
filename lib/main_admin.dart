import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'admin/admin_program_store.dart';
import 'admin/admin_screen.dart';
import 'flow_components.dart';
import 'theme.dart';

/// Internal entrypoint only. Never distribute this build as the consumer app.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StrengthAdminApp());
}

class StrengthAdminApp extends StatefulWidget {
  const StrengthAdminApp({super.key});
  @override
  State<StrengthAdminApp> createState() => _StrengthAdminAppState();
}

class _StrengthAdminAppState extends State<StrengthAdminApp> {
  late Future<AdminProgramStore> _store;
  @override
  void initState() {
    super.initState();
    _store = _open();
  }

  Future<AdminProgramStore> _open() async {
    final directory = await getApplicationSupportDirectory();
    return AdminProgramStore(
      File('${directory.path}/strength-admin/workspace.json'),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Strength 관리자',
    debugShowCheckedModeBanner: false,
    theme: buildConsoleTheme(),
    home: FutureBuilder<AdminProgramStore>(
      future: _store,
      builder: (context, snapshot) {
        if (snapshot.hasData) return AdminScreen(store: snapshot.data!);
        if (snapshot.hasError) {
          return FlowPage(
            title: '프로그램 관리',
            children: [
              StatePanel(
                title: '저장 공간을 열지 못했어요',
                message: '관리자 작업 파일은 변경하지 않았습니다.',
                action: PrimaryAction(
                  label: '다시 시도',
                  onPressed: () => setState(() => _store = _open()),
                ),
              ),
            ],
          );
        }
        return const FlowPage(
          title: '프로그램 관리',
          children: [LinearProgressIndicator()],
        );
      },
    ),
  );
}
