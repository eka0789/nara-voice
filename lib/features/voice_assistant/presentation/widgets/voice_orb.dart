import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/voice/voice_state.dart';

/// NARA's animated voice orb. Every conversation state has a distinct,
/// glanceable visual: idle pulse, listening ripple, thinking orbit,
/// executing ring, speaking glow, awaiting confirmation, error pulse.
class VoiceOrb extends StatefulWidget {
  const VoiceOrb({super.key, required this.state, required this.onTap, this.enabled = true});

  final VoiceState state;
  final VoidCallback onTap;
  final bool enabled;

  @override
  State<VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<VoiceOrb> with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _spin;
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
    _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
    _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _syncControllers();
  }

  @override
  void didUpdateWidget(VoiceOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _syncControllers();
  }

  void _syncControllers() {
    switch (widget.state) {
      case VoiceState.listening:
        _spin.stop();
        _glow.repeat(reverse: true);
      case VoiceState.processing || VoiceState.thinking:
        _spin.repeat();
        _glow.stop();
      case VoiceState.executing:
        _spin.repeat();
        _glow.repeat(reverse: true);
      case VoiceState.speaking:
        _spin.stop();
        _glow.repeat(reverse: true);
      case VoiceState.awaitingConfirmation:
        _spin.stop();
        _glow.repeat(reverse: true);
      case VoiceState.error:
        _spin.stop();
        _glow.repeat(reverse: true);
      case VoiceState.idle:
        _spin.stop();
        _glow.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _spin.dispose();
    _glow.dispose();
    super.dispose();
  }

  Color get _coreColor {
    switch (widget.state) {
      case VoiceState.listening:
        return NaraTheme.accentBlue;
      case VoiceState.processing || VoiceState.thinking:
        return NaraTheme.accentPurple;
      case VoiceState.executing:
        return NaraTheme.accentPurple;
      case VoiceState.speaking:
        return NaraTheme.success;
      case VoiceState.awaitingConfirmation:
        return NaraTheme.warning;
      case VoiceState.error:
        return NaraTheme.danger;
      case VoiceState.idle:
        return NaraTheme.accentPurple;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.state == VoiceState.listening ? 'Stop listening' : 'Start listening',
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulse, _spin, _glow]),
          builder: (context, _) {
            final pulse = _pulse.value;
            final listening = widget.state == VoiceState.listening;
            return SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer ripple(s)
                  if (listening) ..._ripples(pulse),
                  // Rotating orbit arc for thinking/executing
                  if (widget.state.isBusy) _orbit(),
                  // Glow halo
                  _halo(),
                  // Core
                  _core(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _ripples(double t) {
    return [
      for (var i = 0; i < 3; i++)
        Container(
          width: 120 + ((t + i / 3) % 1) * 90,
          height: 120 + ((t + i / 3) % 1) * 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: NaraTheme.accentBlue.withValues(alpha: (1 - ((t + i / 3) % 1)) * 0.5),
              width: 2,
            ),
          ),
        ),
    ];
  }

  Widget _orbit() {
    return RotationTransition(
      turns: _spin,
      child: SizedBox(
        width: 190,
        height: 190,
        child: CustomPaint(painter: _ArcPainter(_coreColor)),
      ),
    );
  }

  Widget _halo() {
    final glow = _glow.value;
    return Container(
      width: 150 + glow * 14,
      height: 150 + glow * 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [_coreColor.withValues(alpha: 0.35 + glow * 0.2), _coreColor.withValues(alpha: 0)],
        ),
      ),
    );
  }

  Widget _core() {
    return Container(
      width: 128,
      height: 128,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            _coreColor.withValues(alpha: 0.95),
            _coreColor.withValues(alpha: 0.65),
            NaraTheme.card,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: _coreColor.withValues(alpha: 0.4),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(
        widget.state == VoiceState.listening ? Icons.mic_rounded : Icons.graphic_eq_rounded,
        color: Colors.white,
        size: 44,
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(colors: [color.withValues(alpha: 0), color]).createShader(
        Offset.zero & size,
      );
    canvas.drawArc(Offset.zero & size, 0, math.pi * 1.4, false, paint);
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) => oldDelegate.color != color;
}
