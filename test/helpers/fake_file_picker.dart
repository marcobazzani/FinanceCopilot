import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// The file picker for widget tests ([FilePickerPlatform.instance]): records
/// every dialog it is asked to open in [calls] (`'pick'` / `'save'`) and
/// [titles], answers a pick with the file at [picked] and a save with the
/// location [saveTo] — null means the user cancelled.
class FakeFilePicker extends FilePickerPlatform {
  String? picked;
  String? saveTo;
  final calls = <String>[];
  final titles = <String?>[];

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    calls.add('pick');
    titles.add(dialogTitle);
    final path = picked;
    return path == null ? null : _LocalFile(path);
  }

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    calls.add('save');
    titles.add(dialogTitle);
    final path = saveTo;
    return path == null ? null : Uri.file(path);
  }
}

/// A picked file on the local disk.
final class _LocalFile extends PlatformFile {
  _LocalFile(this._path);

  final String _path;

  @override
  String get name => Uri.file(_path).pathSegments.last;

  @override
  Uri get uri => Uri.file(_path);

  @override
  get xFile => throw UnimplementedError('the app reads picked files by path');

  @override
  int? lengthSync() => File(_path).lengthSync();

  @override
  Future<int?> length() => File(_path).length();

  @override
  Future<Uint8List> readAsBytes() => File(_path).readAsBytes();

  @override
  Stream<Uint8List> readAsByteStream() => File(_path).openRead().map(Uint8List.fromList);
}
