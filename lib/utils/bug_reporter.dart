import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../services/providers/providers.dart';
import '../version.dart';
import 'logger.dart';

final _log = getLogger('BugReporter');

/// Opens the bug reporter flow. Call from any screen.
/// [repaintKey] — if provided, a screenshot is captured.
/// [enablePrivacy] — if true, privacy mode is toggled on before capturing.
Future<void> openBugReporter(
  BuildContext context,
  WidgetRef ref, {
  GlobalKey? repaintKey,
  bool enablePrivacy = false,
}) async {
  final s = ref.read(appStringsProvider);

  // Step 1: Confirmation dialog with description & steps fields
  final descController = TextEditingController();
  final stepsController = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.bug_report),
          const SizedBox(width: 8),
          Text(s.ticketerTitle),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.ticketerConfirmDesc),
            const SizedBox(height: 12),
            Text(s.ticketerLoginReminder,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: InputDecoration(
                labelText: s.ticketerDescriptionLabel,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
              minLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: stepsController,
              decoration: InputDecoration(
                labelText: s.ticketerStepsLabel,
                hintText: s.ticketerStepsHint,
                border: const OutlineInputBorder(),
              ),
              maxLines: 4,
              minLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false), child: Text(s.cancel)),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.ticketerContinue)),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final userDescription = descController.text.trim();
  final userSteps = stepsController.text.trim();
  descController.dispose();
  stepsController.dispose();

  // Step 2: Collect data
  bool? previousPrivacy;
  if (enablePrivacy) {
    previousPrivacy = ref.read(privacyModeProvider);
    ref.read(privacyModeProvider.notifier).state = true;
    // Wait one frame for the rebuild
    await Future.delayed(const Duration(milliseconds: 100));
    if (!context.mounted) return;
  }

  String? screenshotPath;
  String? logsPath;
  String? saveDir;

  final desktopDir = Platform.isMacOS || Platform.isLinux
      ? p.join(Platform.environment['HOME'] ?? '/tmp', 'Desktop')
      : Platform.environment['USERPROFILE'] != null
          ? p.join(Platform.environment['USERPROFILE']!, 'Desktop')
          : Directory.systemTemp.path;
  final timestamp = DateTime.now()
      .toIso8601String()
      .replaceAll(':', '-')
      .split('.')
      .first;

  try {
    // Capture screenshot
    if (repaintKey != null) {
      final boundary = repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary != null) {
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          saveDir = desktopDir;
          final screenshotFile =
              File(p.join(desktopDir, 'fc-bug-$timestamp.png'));
          await screenshotFile
              .writeAsBytes(byteData.buffer.asUint8List());
          screenshotPath = screenshotFile.path;
        }
      }
    }

    // Extract current session logs and save to file
    if (logFilePath != null) {
      final logContent = await File(logFilePath!).readAsString();
      final lastStart = logContent.lastIndexOf('--- App started at');
      final sessionLogs =
          lastStart >= 0 ? logContent.substring(lastStart) : logContent;
      final logsFile = File(p.join(desktopDir, 'fc-bug-$timestamp.log'));
      await logsFile.writeAsString(sessionLogs);
      logsPath = logsFile.path;
      saveDir = desktopDir;
    }
  } catch (e) {
    _log.warning('Bug reporter capture failed: $e');
  }

  // Restore privacy mode
  if (enablePrivacy && context.mounted) {
    ref.read(privacyModeProvider.notifier).state = previousPrivacy!;
  }

  if (!context.mounted) return;

  // Step 3: Build GitHub issue body & URL
  final descSection = userDescription.isNotEmpty
      ? userDescription
      : '[Describe the issue]';
  final stepsSection = userSteps.isNotEmpty
      ? userSteps
      : '1. ...';

  final bodyParts = StringBuffer()
    ..writeln('**Version:** v$appVersion ($appCommit) [$appChannel]')
    ..writeln(
        '**OS:** ${Platform.operatingSystem} ${Platform.operatingSystemVersion}')
    ..writeln()
    ..writeln('**Description:**')
    ..writeln(descSection)
    ..writeln()
    ..writeln('**Steps to reproduce:**')
    ..writeln(stepsSection)
    ..writeln();

  bodyParts.writeln('**Attachments:** *(drag and drop screenshot and log file below)*');
  bodyParts.writeln();

  final bodyEncoded = Uri.encodeComponent(bodyParts.toString());
  final titleEncoded = Uri.encodeComponent(
      'Bug: ${userDescription.length > 60 ? userDescription.substring(0, 60) : userDescription}');
  final issueUrl = Uri.parse(
    'https://github.com/marcobazzani/FinanceCopilot/issues/new?title=$titleEncoded&body=$bodyEncoded',
  );

  // Step 4: Result dialog — stays open so user can drag-drop screenshot in browser
  if (!context.mounted) return;
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 8),
          Text(s.ticketerTitle),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (screenshotPath != null) ...[
              GestureDetector(
                onTap: () => _showFullScreenshot(ctx, screenshotPath!, s.ticketerScreenshotBanner),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Stack(
                    alignment: Alignment.topRight,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 260),
                          child: Image.file(File(screenshotPath),
                              fit: BoxFit.contain),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(Icons.fullscreen, size: 20,
                            color: Colors.white.withValues(alpha: 0.8)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(s.ticketerTapToPreview,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              const SizedBox(height: 12),
            ],
            if (saveDir != null) ...[
              Text(s.ticketerFilesSaved, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              if (screenshotPath != null)
                Text('  • ${p.basename(screenshotPath)}',
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
              if (logsPath != null)
                Text('  • ${p.basename(logsPath)}',
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(s.ticketerUploadReminder,
                        style: const TextStyle(fontStyle: FontStyle.italic)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: Text(s.ticketerRevealFile),
                    onPressed: () => _revealInFileManager(
                        screenshotPath ?? logsPath!),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton.icon(
          icon: const Icon(Icons.open_in_new),
          label: Text(s.ticketerOpenIssue),
          onPressed: () {
            launchUrl(issueUrl, mode: LaunchMode.externalApplication);
          },
        ),
        TextButton(
            onPressed: () {
              // Clean up temp files
              if (screenshotPath != null) {
                File(screenshotPath).delete().ignore();
              }
              if (logsPath != null) {
                File(logsPath).delete().ignore();
              }
              Navigator.pop(ctx);
            },
            child: Text(s.ticketerClose)),
      ],
    ),
  );
}

/// Opens the system file manager with the given file selected.
Future<void> _revealInFileManager(String filePath) async {
  if (Platform.isMacOS) {
    await Process.run('open', ['-R', filePath]);
  } else if (Platform.isWindows) {
    await Process.run('explorer', ['/select,', filePath]);
  } else if (Platform.isLinux) {
    await Process.run('xdg-open', [p.dirname(filePath)]);
  }
}

/// Shows the screenshot in a fullscreen dialog for validation.
void _showFullScreenshot(BuildContext context, String path, String bannerText) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (context, _, _) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(File(path), fit: BoxFit.contain),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.orange.shade800.withValues(alpha: 0.9),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(bannerText,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
