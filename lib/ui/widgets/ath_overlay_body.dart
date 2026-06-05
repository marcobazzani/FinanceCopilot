part of 'ath_celebration_overlay.dart';

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
          // Purely decorative — clicks pass straight through to the
          // dashboard so the celebration never interrupts what the user
          // is doing. The cards auto-dismiss after _cardLifetime each.
          child: IgnorePointer(
            ignoring: true,
            child: Stack(
              children: [
                _buildStarburstLayer(),
                _buildConfettiLayer(),
                _FireworksLayer(fireGen: controller.fireGen),
                _buildCartelLayer(context),
              ],
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

class _AthCartelCardState extends ConsumerState<_AthCartelCard> with TickerProviderStateMixin {
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
