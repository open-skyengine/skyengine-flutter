import 'dart:io';

class LocalMrpFiles {
  final Set<String> _hiddenMrpPaths = {};

  List<FileSystemEntity> scan(String mrpDirPath) {
    final dir = Directory(mrpDirPath);
    final files = dir
        .listSync()
        .where(
          (e) =>
              e is File &&
              e.path.toLowerCase().endsWith('.mrp') &&
              !_hiddenMrpPaths.contains(fileListKey(e.path)),
        )
        .toList();
    files.sort((a, b) => fileName(a.path).compareTo(fileName(b.path)));
    return files;
  }

  void hide(String path) {
    _hiddenMrpPaths.add(fileListKey(path));
  }

  void unhide(String path) {
    _hiddenMrpPaths.remove(fileListKey(path));
  }

  Future<bool> deleteFile(String path) async {
    final file = File(path);
    final existed = await file.exists();
    if (existed) {
      await file.delete();
    }
    unhide(path);
    return existed;
  }

  String fileListKey(String path) => File(path).absolute.path;

  String fileName(String path) => path.split(Platform.pathSeparator).last;
}
