import 'package:flutter/material.dart';

import '../../domain/input/input_controller.dart';
import '../../domain/session/game_session.dart';

class TouchControls extends StatelessWidget {
  const TouchControls({
    required this.input,
    required this.session,
    required this.playground,
    this.voltChallenge = false,
    super.key,
  });

  final InputController input;
  final GameSession session;
  final bool playground;
  final bool voltChallenge;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        final showDash =
            !voltChallenge &&
            (playground || session.progress.abilities.contains('dash'));
        final showDown =
            !voltChallenge &&
            (playground || session.progress.abilities.contains('downStrike'));
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _HoldButton(
                icon: Icons.arrow_left,
                action: GameAction.left,
                source: 'touch-left',
                input: input,
              ),
              const SizedBox(width: 10),
              _HoldButton(
                icon: Icons.arrow_right,
                action: GameAction.right,
                source: 'touch-right',
                input: input,
              ),
              if (showDown) ...[
                const SizedBox(width: 10),
                _HoldButton(
                  icon: Icons.arrow_downward,
                  action: GameAction.down,
                  source: 'touch-down',
                  input: input,
                  size: 62,
                ),
              ],
              const Spacer(),
              _HoldButton(
                label: 'ATQ',
                action: GameAction.attack,
                source: 'touch-attack',
                input: input,
              ),
              if (showDash) ...[
                const SizedBox(width: 12),
                _HoldButton(
                  label: 'DASH',
                  action: GameAction.dash,
                  source: 'touch-dash',
                  input: input,
                ),
              ],
              const SizedBox(width: 12),
              _HoldButton(
                label: 'SALTO',
                action: GameAction.jump,
                source: 'touch-jump',
                input: input,
                size: 86,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HoldButton extends StatefulWidget {
  const _HoldButton({
    required this.action,
    required this.source,
    required this.input,
    this.icon,
    this.label,
    this.size = 72,
  });

  final GameAction action;
  final String source;
  final InputController input;
  final IconData? icon;
  final String? label;
  final double size;

  @override
  State<_HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<_HoldButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
    if (value) {
      widget.input.press(widget.action, widget.source);
    } else {
      widget.input.release(widget.action, widget.source);
    }
  }

  @override
  void dispose() {
    widget.input.release(widget.action, widget.source);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        width: widget.size,
        height: widget.size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _pressed ? const Color(0xCC42DCEB) : const Color(0x66284B58),
          border: Border.all(color: const Color(0xAA78F3FF), width: 2),
        ),
        child: widget.icon != null
            ? Icon(widget.icon, size: 42, color: Colors.white)
            : Text(
                widget.label!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
      ),
    );
  }
}
