enum GameAction { left, right, down, jump, attack, dash, pause }

class PlayerInputFrame {
  const PlayerInputFrame({
    required this.horizontal,
    required this.downHeld,
    required this.jumpHeld,
    required this.jumpPressed,
    required this.attackPressed,
    required this.dashPressed,
  });

  final double horizontal;
  final bool downHeld;
  final bool jumpHeld;
  final bool jumpPressed;
  final bool attackPressed;
  final bool dashPressed;
}

class InputController {
  final Map<GameAction, Set<String>> _sources = {
    for (final action in GameAction.values) action: <String>{},
  };
  final Set<GameAction> _pressedSinceLastFrame = {};

  bool isHeld(GameAction action) => _sources[action]!.isNotEmpty;

  void press(GameAction action, String source) {
    final sources = _sources[action]!;
    final wasHeld = sources.isNotEmpty;
    sources.add(source);
    if (!wasHeld) _pressedSinceLastFrame.add(action);
  }

  void release(GameAction action, String source) {
    _sources[action]!.remove(source);
  }

  void setSource(GameAction action, String source, {required bool active}) {
    if (active) {
      press(action, source);
    } else {
      release(action, source);
    }
  }

  PlayerInputFrame consumeFrame() {
    final horizontal =
        (isHeld(GameAction.right) ? 1.0 : 0.0) -
        (isHeld(GameAction.left) ? 1.0 : 0.0);
    final frame = PlayerInputFrame(
      horizontal: horizontal,
      downHeld: isHeld(GameAction.down),
      jumpHeld: isHeld(GameAction.jump),
      jumpPressed: _pressedSinceLastFrame.contains(GameAction.jump),
      attackPressed: _pressedSinceLastFrame.contains(GameAction.attack),
      dashPressed: _pressedSinceLastFrame.contains(GameAction.dash),
    );
    _pressedSinceLastFrame.clear();
    return frame;
  }

  void releaseAll() {
    for (final sources in _sources.values) {
      sources.clear();
    }
    _pressedSinceLastFrame.clear();
  }
}
