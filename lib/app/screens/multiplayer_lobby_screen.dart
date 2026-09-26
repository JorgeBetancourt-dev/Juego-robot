import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/progression/game_progress.dart';
import '../../domain/session/game_session.dart';
import '../../infrastructure/network/multiplayer_client.dart';
import 'game_screen.dart';

class MultiplayerLobbyScreen extends StatefulWidget {
  const MultiplayerLobbyScreen({super.key});

  @override
  State<MultiplayerLobbyScreen> createState() => _MultiplayerLobbyScreenState();
}

class _MultiplayerLobbyScreenState extends State<MultiplayerLobbyScreen> {
  late final MultiplayerClient _client;
  late final String _playerName;

  @override
  void initState() {
    super.initState();
    _client = MultiplayerClient();
    _playerName = 'M-0-${100 + Random().nextInt(900)}';
    _connect();
  }

  Future<void> _connect() async {
    try {
      await _client.connect(_playerName);
    } on Object {
      // El estado y el mensaje se muestran mediante AnimatedBuilder.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MODO MULTIJUGADOR'),
        actions: [
          IconButton(
            tooltip: 'Actualizar salas',
            onPressed: _client.isConnected ? _client.refreshRooms : null,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _client,
        builder: (context, _) => switch (_client.status) {
          MultiplayerConnectionStatus.connecting => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('CONECTANDO AL SERVIDOR...'),
                SizedBox(height: 8),
                Text(
                  'La primera conexión puede tardar hasta un minuto.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          MultiplayerConnectionStatus.error ||
          MultiplayerConnectionStatus.disconnected => _ConnectionError(
            message: _client.errorMessage ?? 'Servidor no disponible.',
            onRetry: _connect,
          ),
          MultiplayerConnectionStatus.connected => _roomBrowser(),
        },
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _client,
        builder: (context, _) => FloatingActionButton.extended(
          onPressed: _client.isConnected ? _createRoom : null,
          icon: const Icon(Icons.add),
          label: const Text('CREAR SALA'),
        ),
      ),
    );
  }

  Widget _roomBrowser() {
    if (_client.rooms.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'NO HAY SALAS DISPONIBLES\nCrea la primera sala para comenzar.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        _client.refreshRooms();
        await Future<void>.delayed(const Duration(milliseconds: 400));
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
        itemCount: _client.rooms.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final room = _client.rooms[index];
          return Card(
            child: ListTile(
              leading: const Icon(Icons.groups),
              title: Text(room.name),
              subtitle: Text(
                '${room.playerCount}/${room.maxPlayers} jugadores',
              ),
              trailing: FilledButton(
                onPressed: room.playerCount < room.maxPlayers
                    ? () => _enterRoom(() => _client.joinRoom(room.id))
                    : null,
                child: const Text('ENTRAR'),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _createRoom() async {
    final controller = TextEditingController(text: 'Sala de $_playerName');
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('CREAR SALA'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 32,
          decoration: const InputDecoration(labelText: 'Nombre de la sala'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('CREAR'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    await _enterRoom(() => _client.createRoom(name));
  }

  Future<void> _enterRoom(Future<MultiplayerRoom> Function() action) async {
    try {
      final room = await action();
      if (!mounted) return;
      const progress = GameProgress(
        abilities: {'dash', 'wallJump', 'downStrike', 'doubleJump'},
      );
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GameScreen(
            session: GameSession.temporary(progress: progress),
            playground: false,
            multiplayer: true,
            multiplayerClient: _client,
            multiplayerRoom: room,
          ),
        ),
      );
      _client.leaveRoom();
      _client.refreshRooms();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }
}

class _ConnectionError extends StatelessWidget {
  const _ConnectionError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 54),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton(onPressed: onRetry, child: const Text('REINTENTAR')),
          ],
        ),
      ),
    );
  }
}
