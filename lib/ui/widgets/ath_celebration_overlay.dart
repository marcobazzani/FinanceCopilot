import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/providers/providers.dart';

part 'ath_overlay_body.dart';
part 'ath_fireworks.dart';

/// Chart titles eligible for the ATH celebration (auto-fire scope AND
/// 6-tap easter-egg scope — both must match this set). Match is exact
/// on the raw title as stored in `dashboard_charts.title`.
const Set<String> kAthEligibleLabels = {
  'Total Assets',
  'Portfolio',
  'Performance',
};

/// Public helper for the 6-tap easter-egg counter. Pure function — given
/// the prior tap state (or null for the first tap) and a wall-clock time,
/// returns the next state and whether the threshold was reached. Lives at
/// the library top level so the tap counter logic is unit-testable
/// without touching the private `_SummaryTotalsTableState`.
class AthTapCounter {
  /// Maximum gap between taps for them to count toward the same streak.
  static const Duration window = Duration(milliseconds: 1500);

  /// Number of fast taps required to fire the easter egg.
  static const int threshold = 6;

  /// Compute the next state of the per-row tap counter.
  ///
  /// Returns a record with:
  ///   - `state`: the updated `(count, last)` to store for the row, or
  ///     `null` if the streak just fired and should reset.
  ///   - `fire`: `true` if the threshold was reached on this tap.
  static ({({int count, DateTime last})? state, bool fire}) next(
    ({int count, DateTime last})? prev,
    DateTime now,
  ) {
    final withinWindow = prev != null && now.difference(prev.last) <= window;
    final nextCount = withinWindow ? prev.count + 1 : 1;
    if (nextCount >= threshold) {
      return (state: null, fire: true);
    }
    return (state: (count: nextCount, last: now), fire: false);
  }
}

/// One active celebration card shown inside the overlay.
class AthCard {
  final String label;
  final DateTime shownAt;
  final Color accent;

  AthCard(this.label, this.shownAt, this.accent);
}

/// Drives the ATH celebration overlay. Lifecycle is bound to the screen
/// that owns it (typically `_DashboardScreenState`): the screen creates
/// it in `initState` and disposes it in `dispose`. Calling [fire] either
/// inserts the overlay if none is up, or appends a new card if one is
/// already showing — that's how multiple concurrent ATHs render together.
class AthCelebrationController extends ChangeNotifier {
  static const Duration _cardLifetime = Duration(seconds: 9);
  static const Duration _confettiPlayDuration = Duration(seconds: 7);
  static const Duration _starburstPlayDuration = Duration(seconds: 5);

  /// Confetti emitters: 4 corners + 2 side-emitters near the screen midline.
  static const int _confettiCount = 6;

  /// Mid-screen "starburst" emitters — explode in all directions for the
  /// hero-burst feel right behind the cartel.
  static const int _starburstCount = 3;

  final List<AthCard> _cards = [];
  final List<ConfettiController> _confetti = [];
  final List<ConfettiController> _starbursts = [];
  final List<Timer> _pendingTimers = [];
  OverlayEntry? _entry;
  bool _disposed = false;

  /// Monotonically incremented on each [fire]. Consumed by
  /// [_FireworksLayer] to detect a new fire and spawn a fresh batch of
  /// shells.
  int _fireGen = 0;

  AthCelebrationController() {
    for (var i = 0; i < _confettiCount; i++) {
      _confetti.add(ConfettiController(duration: _confettiPlayDuration));
    }
    for (var i = 0; i < _starburstCount; i++) {
      _starbursts.add(ConfettiController(duration: _starburstPlayDuration));
    }
  }

  List<AthCard> get cards => List.unmodifiable(_cards);

  /// Dismiss every currently-shown card and tear the overlay down. The
  /// "tap anywhere to dismiss" handler in [_AthOverlayBody] calls this.
  void dismissAll() {
    if (_cards.isEmpty && _entry == null) return;
    _cards.clear();
    notifyListeners();
    _entry?.remove();
    _entry = null;
  }

  /// Fire the celebration for [label]. Inserts the overlay on first call,
  /// or appends a card to the existing overlay on subsequent calls.
  void fire(BuildContext context, String label, {Color? accent}) {
    if (_disposed) return;
    final effectiveAccent = accent ?? _defaultAccentFor(context, label);
    _cards.add(AthCard(label, DateTime.now(), effectiveAccent));
    _fireGen++;
    notifyListeners();

    // (Re)trigger confetti each fire so successive 6-taps feel alive.
    for (final c in _confetti) {
      c.play();
    }
    // Starbursts: immediate explosion behind the cartel — sells the
    // "BIG bang" feel right before the rocket shells start climbing.
    for (final c in _starbursts) {
      c.play();
    }
    // Real fireworks (shells with rise + burst) are owned by
    // _FireworksLayer; the fireGen++ above signals it to launch a new
    // batch of shells with randomised peaks.

    if (_entry == null) {
      final overlay = Overlay.of(context, rootOverlay: true);
      _entry = OverlayEntry(builder: (ctx) => _AthOverlayBody(controller: this));
      overlay.insert(_entry!);
    }

    // Schedule per-card auto-dismiss.
    _scheduleTimer(_cardLifetime, () {
      if (_disposed) return;
      // Remove the oldest matching card (a label may appear twice if the
      // user 6-taps and the auto-fire both fire it; auto-dismiss them in
      // FIFO order).
      final idx = _cards.indexWhere((c) => c.label == label);
      if (idx >= 0) {
        _cards.removeAt(idx);
        notifyListeners();
      }
      if (_cards.isEmpty) {
        _entry?.remove();
        _entry = null;
      }
    });
  }

  /// Start a one-shot timer whose handle we track so [dispose] can cancel
  /// it. Returns the timer for callers who need a reference.
  Timer _scheduleTimer(Duration duration, VoidCallback action) {
    late Timer t;
    t = Timer(duration, () {
      _pendingTimers.remove(t);
      action();
    });
    _pendingTimers.add(t);
    return t;
  }

  /// Default accent colour for a known label. Falls back to
  /// `colorScheme.primary` for any label not in the static map.
  Color _defaultAccentFor(BuildContext context, String label) {
    final cs = Theme.of(context).colorScheme;
    switch (label) {
      case 'Total Assets':
        return cs.primary;
      case 'Portfolio':
        return cs.tertiary;
      case 'Performance':
        return cs.secondary;
      default:
        return cs.primary;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final t in _pendingTimers) {
      t.cancel();
    }
    _pendingTimers.clear();
    _entry?.remove();
    _entry = null;
    for (final c in _confetti) {
      c.dispose();
    }
    for (final c in _starbursts) {
      c.dispose();
    }
    super.dispose();
  }

  // Visible for tests.
  @visibleForTesting
  List<ConfettiController> get confettiControllers => _confetti;
  @visibleForTesting
  List<ConfettiController> get starburstControllers => _starbursts;
  // Public — _FireworksLayer reads this to detect new fires.
  int get fireGen => _fireGen;
}
