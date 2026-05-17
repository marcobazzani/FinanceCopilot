import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/providers/providers.dart';

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

/// The widget rendered inside the OverlayEntry. Rebuilds when the
/// controller's card list changes. Splits into three layers:
/// background confetti, fireworks rockets, and the stacked cartel cards.
class _AthOverlayBody extends StatelessWidget {
  final AthCelebrationController controller;
  const _AthOverlayBody({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (ctx, _) {
        return Positioned.fill(
          child: IgnorePointer(
            ignoring: false,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              // Tap anywhere dismisses all currently-shown cards.
              onTap: controller.dismissAll,
              child: Stack(
                children: [
                  _buildStarburstLayer(),
                  _buildConfettiLayer(),
                  _FireworksLayer(fireGen: controller.fireGen),
                  _buildCartelLayer(context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static const _confettiPalette = [
    Color(0xFFFFD54F), // amber 300
    Color(0xFFFF4081), // pink A200
    Color(0xFF40C4FF), // light-blue A200
    Color(0xFF69F0AE), // green A200
    Color(0xFFB388FF), // deep-purple A100
    Color(0xFFFF6E40), // deep-orange A200
    Color(0xFFFFFFFF), // white sparks
    Color(0xFFFFEB3B), // yellow 500 (firework cores)
  ];

  Widget _buildConfettiLayer() {
    // 6 emitters: 4 corners + 2 mid-edges. The mid-edge cannons fire
    // diagonally inward at a steep angle so the screen feels enveloped.
    final alignments = const [
      Alignment.topLeft,
      Alignment.topRight,
      Alignment.bottomLeft,
      Alignment.bottomRight,
      Alignment(-1.0, 0.0), // mid-left
      Alignment(1.0, 0.0), // mid-right
    ];
    final blastDirections = const [
      math.pi / 4, // TL → down-right
      3 * math.pi / 4, // TR → down-left
      -math.pi / 4, // BL → up-right
      -3 * math.pi / 4, // BR → up-left
      0.0, // mid-left → right
      math.pi, // mid-right → left
    ];
    return Stack(
      children: List.generate(controller._confetti.length, (i) {
        return Align(
          alignment: alignments[i],
          child: ConfettiWidget(
            confettiController: controller._confetti[i],
            blastDirection: blastDirections[i],
            blastDirectionality: BlastDirectionality.directional,
            emissionFrequency: 0.08,
            numberOfParticles: 35,
            minBlastForce: 30,
            maxBlastForce: 80,
            minimumSize: const Size(12, 6),
            maximumSize: const Size(22, 10),
            particleDrag: 0.05,
            gravity: 0.2,
            shouldLoop: false,
            colors: _confettiPalette,
          ),
        );
      }),
    );
  }

  Widget _buildStarburstLayer() {
    // Mid-screen explosive bursts — fire in every direction (the
    // BlastDirectionality.explosive mode). Three centred-ish positions
    // produce overlapping fireworks behind the cartel.
    final alignments = const [
      Alignment(-0.3, -0.2),
      Alignment(0.0, 0.0),
      Alignment(0.3, -0.1),
    ];
    return Stack(
      children: List.generate(controller._starbursts.length, (i) {
        return Align(
          alignment: alignments[i],
          child: ConfettiWidget(
            confettiController: controller._starbursts[i],
            blastDirectionality: BlastDirectionality.explosive,
            emissionFrequency: 0.0, // one big burst, then stop
            numberOfParticles: 100,
            minBlastForce: 30,
            maxBlastForce: 70,
            minimumSize: const Size(10, 10),
            maximumSize: const Size(18, 18),
            particleDrag: 0.04,
            gravity: 0.18,
            shouldLoop: false,
            colors: _confettiPalette,
          ),
        );
      }),
    );
  }

  Widget _buildCartelLayer(BuildContext context) {
    final cards = controller.cards;
    if (cards.isEmpty) return const SizedBox.shrink();
    return Center(
      child: SingleChildScrollView(
        // Allow the stack to scroll if many cards pile up at once.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final card in cards) ...[
              _AthCartelCard(card: card),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

/// A single celebration card inside the cartel column. Pops in via a
/// brief scale + fade animation so the cartel feels alive when a fire
/// lands. Larger sizing than a standard card — this is the hero element.
class _AthCartelCard extends ConsumerStatefulWidget {
  final AthCard card;
  const _AthCartelCard({required this.card});

  @override
  ConsumerState<_AthCartelCard> createState() => _AthCartelCardState();
}

class _AthCartelCardState extends ConsumerState<_AthCartelCard>
    with TickerProviderStateMixin {
  late final AnimationController _popIn;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  /// Damped oscillation that drives the cartel's bouncing motion. Plays
  /// once over the card's full lifetime: starts with a big, fast swing
  /// after the pop-in and gradually damps to a near-still settled pose.
  /// `_floatBounce.value` is `t ∈ [0,1]` along the lifetime.
  late final AnimationController _floatBounce;

  /// Total animation length — must match (or stay shorter than) the
  /// card lifetime in [AthCelebrationController._cardLifetime] so the
  /// motion is still active for the whole time the cartel is on screen.
  static const Duration _floatDuration = Duration(seconds: 9);

  /// Number of full oscillations across the lifetime. Higher = bouncier.
  static const double _floatCycles = 5.5;

  /// Exponential decay rate of the amplitude envelope. After t=1 the
  /// remaining amplitude is `exp(-_floatDecay) ≈ 4.5%` of the start.
  static const double _floatDecay = 3.1;

  /// Peak vertical bob amplitude (px) right after the pop-in.
  static const double _floatBobPx = 32.0;

  /// Peak roll amplitude (radians) right after the pop-in (~5.7°).
  static const double _floatRoll = 0.10;

  @override
  void initState() {
    super.initState();
    _popIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scale = CurvedAnimation(parent: _popIn, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _popIn, curve: Curves.easeOut);
    _floatBounce = AnimationController(
      vsync: this,
      duration: _floatDuration,
    )..forward();
    _popIn.forward();
  }

  @override
  void dispose() {
    _popIn.dispose();
    _floatBounce.dispose();
    super.dispose();
  }

  AthCard get card => widget.card;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appStringsProvider);
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: Listenable.merge([_popIn, _floatBounce]),
      builder: (ctx, child) {
        // Damped sinusoid: fast + tall at the start, slowing and shrinking
        // until the cartel is almost still by the time it auto-dismisses.
        // amplitude = peak * exp(-decay * t)
        // phase     = 2π * cycles * t
        // The two amplitudes share a phase but differ in frequency so the
        // bob and tilt don't move in perfect lock-step.
        final t = _floatBounce.value;
        final envelope = math.exp(-_floatDecay * t);
        final phase = 2 * math.pi * _floatCycles * t;
        final bob = math.sin(phase) * _floatBobPx * envelope;
        final tilt = math.sin(phase * 0.6 + 0.4) * _floatRoll * envelope;
        return Opacity(
          opacity: _fade.value,
          child: Transform.translate(
            offset: Offset(0, bob),
            child: Transform.rotate(
              angle: tilt,
              child: Transform.scale(
                // ElasticOut overshoots above 1.0 — that's the "pop" feel.
                scale: 0.6 + 0.5 * _scale.value,
                child: child,
              ),
            ),
          ),
        );
      },
      child: Material(
        elevation: 24,
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        shadowColor: card.accent.withValues(alpha: 0.6),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.surface,
                Color.alphaBlend(
                  card.accent.withValues(alpha: 0.12),
                  theme.colorScheme.surface,
                ),
              ],
            ),
            border: Border.all(color: card.accent, width: 3),
          ),
          padding: const EdgeInsets.fromLTRB(28, 24, 32, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.athCelebrationTitle.toUpperCase(),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: card.accent,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                card.label,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────
// Fireworks layer — real shells with rise + burst phases, drawn via
// CustomPainter. Each call to AthCelebrationController.fire() bumps
// fireGen, which makes this widget spawn a fresh batch of shells with
// randomised peak positions and colours. The internal AnimationController
// ticks every frame while shells are alive, then idles to save CPU.
// ────────────────────────────────────────────────────────────────────────

class _FireworksLayer extends StatefulWidget {
  final int fireGen;
  const _FireworksLayer({required this.fireGen});

  @override
  State<_FireworksLayer> createState() => _FireworksLayerState();
}

class _FireworksLayerState extends State<_FireworksLayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final List<_Shell> _shells = [];
  final math.Random _rnd = math.Random();
  Duration _lastTick = Duration.zero;

  // Palette — saturated, firework-y. Each shell picks one color so its
  // rocket + sparks look like one cohesive burst.
  static const List<Color> _palette = [
    Color(0xFFFFEB3B), // yellow
    Color(0xFFFF4081), // pink
    Color(0xFF40C4FF), // light blue
    Color(0xFF69F0AE), // green
    Color(0xFFB388FF), // purple
    Color(0xFFFF6E40), // orange
    Color(0xFFFFFFFF), // white sparks
    Color(0xFFFF1744), // red
    Color(0xFF00E5FF), // cyan
  ];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _spawnBatch();
    _ticker.start();
  }

  @override
  void didUpdateWidget(_FireworksLayer old) {
    super.didUpdateWidget(old);
    if (old.fireGen != widget.fireGen) {
      _spawnBatch();
      if (!_ticker.isActive) _ticker.start();
    }
  }

  /// Launch a fresh wave of 20 shells with staggered launch times and
  /// peaks spread across the upper 60% of the screen. Each shell is
  /// allowed to spawn 2-3 secondary "child" shells from its burst, so
  /// the show keeps cascading well past the last initial launch.
  void _spawnBatch() {
    const shellsPerBatch = 20;
    for (var i = 0; i < shellsPerBatch; i++) {
      _shells.add(_buildPrimaryShell(launchDelayMs: i * 250));
    }
    _lastTick = Duration.zero;
  }

  _Shell _buildPrimaryShell({required int launchDelayMs}) {
    final shellType = _ShellType.values[_rnd.nextInt(_ShellType.values.length)];
    return _Shell(
      startX: 0.05 + _rnd.nextDouble() * 0.9,
      peakX: 0.1 + _rnd.nextDouble() * 0.8,
      peakY: 0.05 + _rnd.nextDouble() * 0.5, // upper 55% of screen
      color: _palette[_rnd.nextInt(_palette.length)],
      secondaryColor: _palette[_rnd.nextInt(_palette.length)],
      launchDelay: Duration(milliseconds: launchDelayMs),
      sparkCount: 90 + _rnd.nextInt(50),
      rnd: _rnd,
      type: shellType,
      // ~40% chance of secondary cascade. Disabled on the child shells
      // themselves so the recursion stops at one level.
      spawnsChildren: _rnd.nextDouble() < 0.4,
    );
  }

  /// Build a tiny secondary shell starting near an exhausted parent — it
  /// skips the rise phase and explodes right where it was born.
  _Shell _buildChildShell({
    required double centerX,
    required double centerY,
    required Color color,
  }) {
    return _Shell(
      startX: centerX,
      peakX: centerX,
      peakY: centerY,
      color: color,
      secondaryColor: _palette[_rnd.nextInt(_palette.length)],
      launchDelay: Duration.zero,
      sparkCount: 40 + _rnd.nextInt(20),
      rnd: _rnd,
      type: _ShellType.values[_rnd.nextInt(_ShellType.values.length)],
      spawnsChildren: false,
      skipRise: true,
    );
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMilliseconds / 1000.0;
    _lastTick = elapsed;
    final aliveShells = <_Shell>[];
    final newChildren = <_Shell>[];
    for (final shell in _shells) {
      shell.advance(dt);
      if (shell.shouldSpawnChildren) {
        shell.markChildrenSpawned();
        // Spawn 2-3 children at random spark positions near the parent's
        // peak; their colours echo the parent so the cascade reads as
        // one continuous explosion rather than random pops.
        final n = 2 + _rnd.nextInt(2);
        for (var k = 0; k < n; k++) {
          final dx = (_rnd.nextDouble() - 0.5) * 0.18;
          final dy = (_rnd.nextDouble() - 0.5) * 0.12;
          newChildren.add(_buildChildShell(
            centerX: (shell.peakX + dx).clamp(0.05, 0.95),
            centerY: (shell.peakY + dy).clamp(0.05, 0.85),
            color: k.isEven ? shell.color : shell.secondaryColor,
          ));
        }
      }
      if (!shell.isDone) aliveShells.add(shell);
    }
    _shells
      ..clear()
      ..addAll(aliveShells)
      ..addAll(newChildren);
    if (_shells.isEmpty) {
      _ticker.stop();
      _lastTick = Duration.zero;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _FireworksPainter(shells: List.unmodifiable(_shells)),
      ),
    );
  }
}

enum _ShellType {
  /// Single dense radial ring of sparks — the classic.
  chrysanthemum,

  /// Two concentric rings: a slow halo + a fast outer corona, mixing
  /// the primary and secondary colours.
  doubleRing,

  /// Sparks fall slowly with stronger gravity (drooping willow look).
  willow,
}

class _Shell {
  // Position fractions are 0..1 of the canvas (peakY: 0 = top).
  final double startX;
  final double peakX;
  final double peakY;
  final Color color;
  final Color secondaryColor;
  final Duration launchDelay;
  final _ShellType type;
  final bool spawnsChildren;
  final bool skipRise;
  final List<_Spark> sparks;

  /// Rocket climb time.
  static const double _rise = 0.7;

  /// Burst lifetime — long enough for sparks to fade out gracefully.
  static const double _burst = 2.2;

  /// Time since spawn (after [launchDelay]); negative while waiting on
  /// the delay.
  double _t = 0.0;
  bool _delayed = true;
  bool _childrenSpawned = false;

  _Shell({
    required this.startX,
    required this.peakX,
    required this.peakY,
    required this.color,
    required this.secondaryColor,
    required this.launchDelay,
    required int sparkCount,
    required math.Random rnd,
    required this.type,
    this.spawnsChildren = false,
    this.skipRise = false,
  }) : sparks = _buildSparks(type, sparkCount, rnd) {
    if (skipRise) {
      _delayed = false;
      _t = _rise; // jump directly to the start of the burst
    }
  }

  static List<_Spark> _buildSparks(
      _ShellType type, int count, math.Random rnd) {
    return List.generate(count, (_) {
      final angle = rnd.nextDouble() * 2 * math.pi;
      switch (type) {
        case _ShellType.chrysanthemum:
          // Two speed populations — fast core + slow trail = denser ring.
          final fast = rnd.nextDouble() < 0.7;
          final speed = fast
              ? 0.30 + rnd.nextDouble() * 0.28
              : 0.10 + rnd.nextDouble() * 0.12;
          return _Spark(
            angle: angle,
            speed: speed,
            ring: fast ? _Ring.outer : _Ring.inner,
            extraGravity: 0.0,
          );
        case _ShellType.doubleRing:
          // Half the sparks form the outer fast ring, the other half a
          // slower inner halo in the secondary colour.
          final outer = rnd.nextBool();
          final speed = outer
              ? 0.45 + rnd.nextDouble() * 0.15
              : 0.18 + rnd.nextDouble() * 0.10;
          return _Spark(
            angle: angle,
            speed: speed,
            ring: outer ? _Ring.outer : _Ring.inner,
            extraGravity: 0.0,
          );
        case _ShellType.willow:
          // Willow: sparks blossom outward then fall hard. Lower lateral
          // velocity, higher gravity.
          return _Spark(
            angle: angle,
            speed: 0.20 + rnd.nextDouble() * 0.12,
            ring: _Ring.outer,
            extraGravity: 80.0,
          );
      }
    });
  }

  void advance(double dt) {
    if (_delayed) {
      _t -= dt;
      if (_t <= -launchDelay.inMilliseconds / 1000.0) {
        _delayed = false;
        _t = 0.0;
      } else if (_t < 0) {
        return;
      } else {
        _t = -dt;
        return;
      }
    }
    _t += dt;
  }

  bool get isDone => !_delayed && _t > _rise + _burst;
  bool get isRising => !_delayed && !skipRise && _t < _rise;
  bool get isExploding => !_delayed && _t >= _rise && _t < _rise + _burst;
  bool get isWaiting => _delayed;

  /// Progress 0..1 through the rise phase.
  double get riseProgress => (_t / _rise).clamp(0.0, 1.0);

  /// Progress 0..1 through the explosion phase.
  double get burstProgress => ((_t - _rise) / _burst).clamp(0.0, 1.0);

  /// True at the moment the parent shell's burst is ~40% through and we
  /// haven't yet birthed the child shells. The tick handler reads this
  /// to perform the cascade exactly once.
  bool get shouldSpawnChildren =>
      spawnsChildren && !_childrenSpawned && burstProgress > 0.35;

  void markChildrenSpawned() => _childrenSpawned = true;
}

enum _Ring { inner, outer }

class _Spark {
  final double angle; // radians
  final double speed; // canvas-fraction per second
  final _Ring ring;
  final double extraGravity; // px/s² added on top of the global gravity
  _Spark({
    required this.angle,
    required this.speed,
    required this.ring,
    required this.extraGravity,
  });
}

class _FireworksPainter extends CustomPainter {
  final List<_Shell> shells;
  _FireworksPainter({required this.shells});

  @override
  void paint(Canvas canvas, Size size) {
    for (final shell in shells) {
      if (shell.isWaiting) continue;
      if (shell.isRising) {
        _paintRocket(canvas, size, shell);
      } else if (shell.isExploding) {
        _paintBurst(canvas, size, shell);
      }
    }
  }

  void _paintRocket(Canvas canvas, Size size, _Shell shell) {
    final eased = Curves.easeOutQuad.transform(shell.riseProgress);
    final x = (shell.startX + (shell.peakX - shell.startX) * eased) * size.width;
    final yEnd = shell.peakY * size.height;
    final yStart = size.height; // bottom of canvas
    final y = yStart + (yEnd - yStart) * eased;
    // Trail: 6 fading dots behind the rocket head.
    for (var i = 0; i < 6; i++) {
      final trailT = (shell.riseProgress - i * 0.05).clamp(0.0, 1.0);
      if (trailT <= 0) continue;
      final trailEased = Curves.easeOutQuad.transform(trailT);
      final tx = (shell.startX + (shell.peakX - shell.startX) * trailEased) * size.width;
      final ty = yStart + (yEnd - yStart) * trailEased;
      final paint = Paint()
        ..color = shell.color.withValues(alpha: (0.9 - i * 0.15).clamp(0.0, 0.9));
      canvas.drawCircle(Offset(tx, ty), 3.5 - i * 0.4, paint);
    }
    // Rocket head — bright + a small white core.
    canvas.drawCircle(Offset(x, y), 4.5, Paint()..color = shell.color);
    canvas.drawCircle(Offset(x, y), 1.8, Paint()..color = Colors.white);
  }

  void _paintBurst(Canvas canvas, Size size, _Shell shell) {
    final p = shell.burstProgress;
    final cx = shell.peakX * size.width;
    final cy = shell.peakY * size.height;
    final maxDimension = math.max(size.width, size.height);
    // Alpha fades faster in the second half so the burst gracefully dies.
    final alpha = p < 0.5
        ? 1.0
        : (1.0 - (p - 0.5) / 0.5).clamp(0.0, 1.0);

    // Brief central flash at the moment of explosion — wider for the
    // longer burst lifetime.
    if (p < 0.18) {
      final flashAlpha = (1.0 - p / 0.18);
      canvas.drawCircle(
        Offset(cx, cy),
        22 + p * 20,
        Paint()..color = Colors.white.withValues(alpha: flashAlpha * 0.85),
      );
    }

    for (final spark in shell.sparks) {
      // Ring choice picks the colour: outer = primary, inner = secondary.
      final sparkColor = spark.ring == _Ring.outer ? shell.color : shell.secondaryColor;
      // Distance grows linearly (canvas-fraction units → pixels) over
      // the full burst lifetime, scaled by speed.
      final distance = spark.speed * p * maxDimension * 0.95;
      final dx = math.cos(spark.angle) * distance;
      // Gravity has a base value (~80 px/s²) plus the shell-type extra
      // gravity for willow-style droop. Multiplying by p*p gives quadratic
      // pull that intensifies the later the spark lives.
      final gravity = 80.0 + spark.extraGravity;
      final dy = math.sin(spark.angle) * distance + gravity * p * p;
      final pos = Offset(cx + dx, cy + dy);

      // Comet trail: 5 faint dots behind the current spark position.
      for (var t = 1; t <= 5; t++) {
        final tp = (p - t * 0.025).clamp(0.0, 1.0);
        if (tp <= 0) continue;
        final td = spark.speed * tp * maxDimension * 0.95;
        final tdx = math.cos(spark.angle) * td;
        final tdy = math.sin(spark.angle) * td + gravity * tp * tp;
        final trailAlpha = alpha * (1.0 - t * 0.18);
        canvas.drawCircle(
          Offset(cx + tdx, cy + tdy),
          2.0 - t * 0.25,
          Paint()..color = sparkColor.withValues(alpha: trailAlpha.clamp(0.0, 1.0)),
        );
      }

      // Spark head.
      final headSize = 2.8 * (1.0 - p * 0.55);
      canvas.drawCircle(
        pos,
        headSize,
        Paint()..color = sparkColor.withValues(alpha: alpha),
      );
      // White core while the spark is still hot.
      if (p < 0.35) {
        canvas.drawCircle(
          pos,
          headSize * 0.5,
          Paint()..color = Colors.white.withValues(alpha: alpha * 0.8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_FireworksPainter old) => true;
}
