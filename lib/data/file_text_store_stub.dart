import 'text_store.dart';

/// Web stub — never constructed on the web boot path.
final class FileTextStore implements TextStore {
  FileTextStore(Object file) {
    throw UnsupportedError('File storage is not available on web');
  }

  @override
  String get id => 'unavailable';

  @override
  Future<bool> exists() async => false;

  @override
  Future<String> read() => throw UnsupportedError('File storage is not available on web');

  @override
  Future<void> write(String text) =>
      throw UnsupportedError('File storage is not available on web');

  @override
  Future<void> delete() async {}

  @override
  TextStore sibling(String name) => this;
}
