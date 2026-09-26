import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

enum MultiplayerConnectionStatus { disconnected, connecting, connected, error }

class MultiplayerRoom {
  const MultiplayerRoom({
    required this.id,
    required this.name,
    required this.playerCount,
    required this.maxPlayers,
  });

  factory MultiplayerRoom.fromJson(Map<String, Object?> json) =>
      MultiplayerRoom(
        id: json['id'] as String,
        name: json['name'] as String,
        playerCount: (json['playerCount'] as num).toInt(),
        maxPlayers: (json['maxPlayers'] as num).toInt(),
      );

  final String id;
  final String name;
  final int playerCount;
  final int maxPlayers;
}

class RemotePlayerSnapshot {
  const RemotePlayerSnapshot({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.facing,
    required this.animation,
  });

  final String id;
  final String name;
  final double x;
  final double y;
  final int facing;
  final String animation;
}

class MultiplayerClient extends ChangeNotifier {
  MultiplayerClient({String? endpoint})
    : endpoint =
          endpoint ??
          const String.fromEnvironment(
            'MULTIPLAYER_URL',
            defaultValue: 'ws://10.0.2.2:8080/ws',
          );

  final String endpoint;
  WebSocket? _socket;
  StreamSubscription<Object?>? _subscription;
  Completer<void>? _welcomeCompleter;
  Completer<MultiplayerRoom>? _joinCompleter;
  DateTime _lastStateSent = DateTime.fromMillisecondsSinceEpoch(0);
  bool _disposed = false;

  MultiplayerConnectionStatus status = MultiplayerConnectionStatus.disconnected;
  String? errorMessage;
  String? playerId;
  String? roomId;
  int spawnIndex = 0;
  List<MultiplayerRoom> rooms = const [];
  final Map<String, RemotePlayerSnapshot> remotePlayers = {};

  bool get isConnected => status == MultiplayerConnectionStatus.connected;

  Future<void> connect(String playerName) async {
    if (_socket != null) return;
    status = MultiplayerConnectionStatus.connecting;
    errorMessage = null;
    notifyListeners();
    _welcomeCompleter = Completer<void>();
    try {
      final socket = await WebSocket.connect(
        endpoint,
      ).timeout(const Duration(seconds: 20));
      _socket = socket;
      _subscription = socket.listen(
        _handleMessage,
        onDone: _handleDisconnect,
        onError: (Object error) => _handleDisconnect(error),
        cancelOnError: true,
      );
      _send({'type': 'hello', 'name': playerName});
      await _welcomeCompleter!.future.timeout(const Duration(seconds: 10));
    } on Object catch (error) {
      _handleDisconnect(error);
      rethrow;
    }
  }

  void refreshRooms() => _send({'type': 'list_rooms'});

  Future<MultiplayerRoom> createRoom(String name) =>
      _join({'type': 'create_room', 'name': name});

  Future<MultiplayerRoom> joinRoom(String id) =>
      _join({'type': 'join_room', 'roomId': id});

  Future<MultiplayerRoom> _join(Map<String, Object> message) async {
    if (_joinCompleter != null) {
      throw StateError('Ya hay una solicitud de entrada en curso.');
    }
    _joinCompleter = Completer<MultiplayerRoom>();
    _send(message);
    try {
      return await _joinCompleter!.future.timeout(const Duration(seconds: 12));
    } finally {
      _joinCompleter = null;
    }
  }

  void leaveRoom() {
    if (roomId == null) return;
    _send({'type': 'leave_room'});
    roomId = null;
    remotePlayers.clear();
    notifyListeners();
  }

  void sendPlayerState({
    required double x,
    required double y,
    required int facing,
    required String animation,
  }) {
    if (roomId == null) return;
    final now = DateTime.now();
    if (now.difference(_lastStateSent) < const Duration(milliseconds: 50)) {
      return;
    }
    _lastStateSent = now;
    _send({
      'type': 'player_state',
      'x': x,
      'y': y,
      'facing': facing,
      'animation': animation,
    });
  }

  void _handleMessage(Object? raw) {
    if (raw is! String) return;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?>) return;
    switch (decoded['type']) {
      case 'welcome':
        playerId = decoded['playerId'] as String;
        status = MultiplayerConnectionStatus.connected;
        _welcomeCompleter?.complete();
        break;
      case 'rooms':
        final values = decoded['rooms'] as List<Object?>? ?? const [];
        rooms = values
            .whereType<Map<String, Object?>>()
            .map(MultiplayerRoom.fromJson)
            .toList(growable: false);
        break;
      case 'room_joined':
        final room = MultiplayerRoom.fromJson(
          decoded['room'] as Map<String, Object?>,
        );
        roomId = room.id;
        spawnIndex = (decoded['spawnIndex'] as num?)?.toInt() ?? 0;
        remotePlayers.clear();
        for (final value in decoded['players'] as List<Object?>? ?? const []) {
          if (value is! Map<String, Object?>) continue;
          final id = value['id'] as String;
          final state = value['state'];
          if (state is Map<String, Object?>) {
            remotePlayers[id] = _snapshot(id, value['name'] as String, state);
          }
        }
        _joinCompleter?.complete(room);
        break;
      case 'player_state':
        final id = decoded['playerId'] as String;
        if (id != playerId) {
          remotePlayers[id] = _snapshot(id, decoded['name'] as String, decoded);
        }
        break;
      case 'player_left':
        remotePlayers.remove(decoded['playerId']);
        break;
      case 'error':
        final message = decoded['message'] as String? ?? 'Error de red.';
        errorMessage = message;
        if (_joinCompleter case final completer? when !completer.isCompleted) {
          completer.completeError(StateError(message));
        }
        break;
    }
    notifyListeners();
  }

  RemotePlayerSnapshot _snapshot(
    String id,
    String name,
    Map<String, Object?> json,
  ) => RemotePlayerSnapshot(
    id: id,
    name: name,
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    facing: (json['facing'] as num?)?.toInt() ?? 1,
    animation: json['animation'] as String? ?? 'idle',
  );

  void _send(Map<String, Object> message) {
    final socket = _socket;
    if (socket?.readyState == WebSocket.open) socket!.add(jsonEncode(message));
  }

  void _handleDisconnect([Object? error]) {
    _socket = null;
    status = error == null
        ? MultiplayerConnectionStatus.disconnected
        : MultiplayerConnectionStatus.error;
    errorMessage = error == null
        ? 'Se perdió la conexión con el servidor.'
        : '$error';
    roomId = null;
    remotePlayers.clear();
    if (_welcomeCompleter case final completer? when !completer.isCompleted) {
      completer.completeError(StateError(errorMessage!));
    }
    if (_joinCompleter case final completer? when !completer.isCompleted) {
      completer.completeError(StateError(errorMessage!));
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    unawaited(_socket?.close());
    super.dispose();
  }
}
