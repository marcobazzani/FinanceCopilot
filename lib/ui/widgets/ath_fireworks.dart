part of 'ath_celebration_overlay.dart';

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

class _FireworksLayerState extends State<_FireworksLayer> with SingleTickerProviderStateMixin {
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
          newChildren.add(
            _buildChildShell(
              centerX: (shell.peakX + dx).clamp(0.05, 0.95),
              centerY: (shell.peakY + dy).clamp(0.05, 0.85),
              color: k.isEven ? shell.color : shell.secondaryColor,
            ),
          );
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

  static List<_Spark> _buildSparks(_ShellType type, int count, math.Random rnd) {
    return List.generate(count, (_) {
      final angle = rnd.nextDouble() * 2 * math.pi;
      switch (type) {
        case _ShellType.chrysanthemum:
          // Two speed populations — fast core + slow trail = denser ring.
          final fast = rnd.nextDouble() < 0.7;
          final speed = fast ? 0.30 + rnd.nextDouble() * 0.28 : 0.10 + rnd.nextDouble() * 0.12;
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
          final speed = outer ? 0.45 + rnd.nextDouble() * 0.15 : 0.18 + rnd.nextDouble() * 0.10;
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
  bool get shouldSpawnChildren => spawnsChildren && !_childrenSpawned && burstProgress > 0.35;

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
      final paint = Paint()..color = shell.color.withValues(alpha: (0.9 - i * 0.15).clamp(0.0, 0.9));
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
    final alpha = p < 0.5 ? 1.0 : (1.0 - (p - 0.5) / 0.5).clamp(0.0, 1.0);

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
