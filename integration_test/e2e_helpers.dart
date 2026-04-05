import 'dart:io';

const _windowX = 200;
const _windowY = 200;
const _windowW = 1200;
const _windowH = 800;

// ── Coordinate system ──────────────────────────────────
// Screenshots are captured at 2x Retina resolution but displayed at half size.
// The 600x400 "display" image maps to the 1200x800 point window.
// Formula: screen_point = window_origin + display_coord * 2

/// Click at a position. [x],[y] are in display image coordinates (600x400 space).
Future<void> click(int x, int y) async {
  final sx = _windowX + x * 2;
  final sy = _windowY + y * 2;
  await Process.run('swift', ['-e', '''
import Cocoa
let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: CGPoint(x: $sx, y: $sy), mouseButton: .left)!
let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: CGPoint(x: $sx, y: $sy), mouseButton: .left)!
down.post(tap: .cghidEventTap)
usleep(50000)
up.post(tap: .cghidEventTap)
''']);
}

/// Double-click at position.
Future<void> doubleClick(int x, int y) async {
  await click(x, y);
  await Future.delayed(const Duration(milliseconds: 100));
  await click(x, y);
}

/// Type text using System Events keystroke.
Future<void> typeText(String text) async {
  // Escape special characters for AppleScript
  final escaped = text.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
  await Process.run('osascript', ['-e',
    'tell application "System Events" to keystroke "$escaped"'
  ]);
}

/// Press a key combo (e.g. "return", "escape", "tab").
Future<void> pressKey(String key) async {
  final code = _keyCodes[key];
  if (code != null) {
    await Process.run('osascript', ['-e',
      'tell application "System Events" to key code $code'
    ]);
  }
}

const _keyCodes = {
  'return': 36, 'escape': 53, 'tab': 48, 'delete': 51,
  'space': 49, 'up': 126, 'down': 125, 'left': 123, 'right': 124,
};

/// Take a screenshot of the app window. Returns file path.
Future<String> screenshot(String name) async {
  final path = '/tmp/e2e_$name.png';
  await Process.run('screencapture', ['-x', '-R',
    '$_windowX,$_windowY,$_windowW,$_windowH', path]);
  return path;
}

Future<void> wait(int seconds) async {
  await Future.delayed(Duration(seconds: seconds));
}

// ── Sidebar navigation (display image coords) ──────────
// Sidebar items are at x=35, vertical spacing ~25px
const _nav = {
  'Dashboard':   (35, 55),
  'Accounts':    (35, 80),
  'Assets':      (35, 105),
  'Adjustments': (35, 130),
  'Income':      (35, 155),
};

/// Navigate to a sidebar screen by name.
Future<void> navigateTo(String screen) async {
  final pos = _nav[screen];
  if (pos == null) throw ArgumentError('Unknown screen: $screen');
  await click(pos.$1, pos.$2);
  await wait(2);
}

// ── Dashboard tabs (display image coords) ──────────────
const _tabs = {
  'Health':          (105, 28),
  'History':         (195, 28),
  'Cash Flow':       (290, 28),
  'Assets Overview': (410, 28),
};

/// Click a dashboard tab by name.
Future<void> dashTab(String tab) async {
  final pos = _tabs[tab];
  if (pos == null) throw ArgumentError('Unknown tab: $tab');
  await click(pos.$1, pos.$2);
  await wait(2);
}

// ── Toolbar buttons (display image coords) ──────────────
const _toolbar = {
  'privacy':    (490, 17),
  'refresh':    (515, 17),
  'importExport': (540, 17),
  'settings':   (560, 17),
  'csvImport':  (585, 17),
};

/// Click a toolbar button by name.
Future<void> toolbar(String button) async {
  final pos = _toolbar[button];
  if (pos == null) throw ArgumentError('Unknown button: $button');
  await click(pos.$1, pos.$2);
  await wait(1);
}

// ── DB Picker ──────────────────────────────────────────

/// Prepare a test DB: generate demo data at a known path,
/// then copy it where the app expects.
/// This avoids using the user's personal DB.
Future<String> prepareTestDb() async {
  final testDbPath = '/tmp/e2e_test_finance.db';
  // Delete old test DB
  final old = File(testDbPath);
  if (old.existsSync()) old.deleteSync();

  // Generate demo DB using the app's DemoDbService via Dart
  await Process.run('dart', ['run', 'integration_test/generate_test_db.dart', testDbPath]);
  return testDbPath;
}

/// Click "Open File..." on the picker screen, then navigate to the test DB.
/// Since native file picker can't be automated, we instead place the test DB
/// at a known recent path so the picker shows it.
Future<void> openTestDb(String testDbPath) async {
  // Copy test DB to Documents so the picker finds it
  final targetPath = '/tmp/FinanceCopilot_e2e_test.db';
  File(testDbPath).copySync(targetPath);

  // Use "Open File..." button — display coords approximately (180, 365)
  await click(180, 365);
  await wait(2);

  // In the native open dialog, type the path and press Enter
  // Cmd+Shift+G opens "Go to folder" in Finder dialogs
  await Process.run('osascript', ['-e', '''
tell application "System Events"
  keystroke "g" using {command down, shift down}
  delay 1
  keystroke "/tmp"
  delay 0.5
  keystroke return
  delay 1
  keystroke "FinanceCopilot_e2e_test.db"
  delay 0.5
  keystroke return
  delay 1
end tell''']);
  await wait(5);
}

/// Click "Allow" on macOS permission dialog (if it appears).
Future<void> allowPermissionDialog() async {
  await click(390, 110);
  await wait(2);
}

// ── App lifecycle ──────────────────────────────────────

/// Position and activate the app window.
Future<void> activateApp() async {
  await Process.run('osascript', ['-e', '''
tell application "System Events"
  tell process "FinanceCopilot"
    set position of window 1 to {$_windowX, $_windowY}
    set size of window 1 to {$_windowW, $_windowH}
    set frontmost to true
  end tell
end tell''']);
  await wait(1);
}

/// Launch the app fresh.
Future<void> launchApp() async {
  await Process.run('pkill', ['-9', '-f', 'FinanceCopilot']);
  await wait(1);
  await Process.run('open', [
    '/Users/marco/Project/FinanceCopilot/build/macos/Build/Products/Release/FinanceCopilot.app'
  ]);
  await wait(5);
  await activateApp();
}

/// Kill the app.
Future<void> killApp() async {
  await Process.run('pkill', ['-f', 'FinanceCopilot']);
}

// ── DB queries ──────────────────────────────────────────

/// Query the SQLite database, returns stdout.
Future<String> queryDb(String dbPath, String sql) async {
  final result = await Process.run('sqlite3', [dbPath, sql]);
  return (result.stdout as String).trim();
}

/// Test DB path (isolated from personal data).
String get dbPath => '/tmp/FinanceCopilot_e2e_test.db';

// ── Assertions ──────────────────────────────────────────

int _passed = 0;
int _failed = 0;

void pass(String name) {
  _passed++;
  print('  PASS: $name');
}

void fail(String name, String reason) {
  _failed++;
  print('  FAIL: $name -- $reason');
  exitCode = 1;
}

void check(bool condition, String name, [String detail = '']) {
  if (condition) {
    pass(name);
  } else {
    fail(name, detail);
  }
}

void printSummary() {
  print('\n=== Results: $_passed passed, $_failed failed ===');
  if (_failed == 0) {
    print('ALL TESTS PASSED');
  } else {
    print('SOME TESTS FAILED');
  }
}
