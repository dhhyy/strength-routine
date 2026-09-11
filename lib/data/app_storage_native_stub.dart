import 'app_storage.dart';

Future<AppStorage> openNativeAppStorage() {
  throw UnsupportedError('Native file storage is not available on web');
}
