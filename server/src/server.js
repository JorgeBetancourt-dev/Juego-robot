import http from 'node:http';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { WebSocket, WebSocketServer } from 'ws';

const MAX_PLAYERS = 4;
const TOTAL_HORDES = 5;
const NORMAL_ENEMY_TYPES = ['patrol', 'watcher', 'drone'];
const PLAYER_NAMES = ['M-0-Rojo', 'M-0-Verde', 'M-0-Azul', 'M-0-Amarillo'];
const allowedAnimations = new Set([
  'idle',
  'run',
  'rise',
  'fall',
  'land',
  'attack',
  'dash',
  'wall_slide',
  'wall_jump',
  'double_jump',
  'down_strike',
  'hurt',
  'death',
  'respawn',
]);

function cleanText(value, fallback, maxLength = 24) {
  if (typeof value !== 'string') return fallback;
  const cleaned = value.replace(/[\u0000-\u001f<>]/g, '').trim();
  return cleaned.length === 0 ? fallback : cleaned.slice(0, maxLength);
}

function send(client, message) {
  if (client.ws.readyState === WebSocket.OPEN) {
    client.ws.send(JSON.stringify(message));
  }
}

function roomSummary(room) {
  return {
    id: room.id,
    name: room.name,
    playerCount: room.clients.size,
    maxPlayers: MAX_PLAYERS,
  };
}

export function enemyCountForHorde(horde, playerCount) {
  if (horde < 1 || horde > TOTAL_HORDES || playerCount < 1) return 0;
  return horde === TOTAL_HORDES ? playerCount : playerCount * (horde + 1);
}

export function enemyTypeForHorde(horde, random = Math.random) {
  if (horde === TOTAL_HORDES) return 'volt';
  return NORMAL_ENEMY_TYPES[Math.floor(random() * NORMAL_ENEMY_TYPES.length)];
}

export function createMultiplayerServer({
  port = Number(process.env.PORT || 8080),
  initialCountdownMs = 5000,
  intermissionMs = 10000,
  hitCooldownMs = 220,
  random = Math.random,
} = {}) {
  const clients = new Map();
  const rooms = new Map();

  const httpServer = http.createServer((request, response) => {
    response.setHeader('Access-Control-Allow-Origin', '*');
    response.setHeader('Content-Type', 'application/json; charset=utf-8');
    if (request.url === '/rooms') {
      response.end(JSON.stringify([...rooms.values()].map(roomSummary)));
      return;
    }
    response.end(JSON.stringify({
      status: 'ok',
      game: 'Sistema Caído',
      rooms: rooms.size,
      players: clients.size,
    }));
  });

  const websocketServer = new WebSocketServer({ server: httpServer, path: '/ws' });

  function availableRooms() {
    return [...rooms.values()]
      .filter((room) => room.clients.size < MAX_PLAYERS)
      .map(roomSummary)
      .sort((a, b) => b.playerCount - a.playerCount || a.name.localeCompare(b.name));
  }

  function broadcastRoomList() {
    const message = { type: 'rooms', rooms: availableRooms() };
    for (const client of clients.values()) send(client, message);
  }

  function broadcast(room, message, exceptId = null) {
    for (const client of room.clients.values()) {
      if (client.id !== exceptId) send(client, message);
    }
  }

  function hordeState(room) {
    return {
      type: 'horde_state',
      phase: room.hordePhase,
      horde: room.horde,
      totalHordes: TOTAL_HORDES,
      intermissionEndsAt: room.intermissionEndsAt,
      intermissionRemainingMs: room.intermissionEndsAt == null
        ? null
        : Math.max(0, room.intermissionEndsAt - Date.now()),
      enemies: [...room.enemies.values()].map((enemy) => ({ ...enemy })),
    };
  }

  function broadcastHordeState(room) {
    broadcast(room, hordeState(room));
  }

  function startHorde(room, horde) {
    if (room.clients.size === 0) return;
    if (room.hordeTimer) clearTimeout(room.hordeTimer);
    room.hordeTimer = null;
    room.horde = horde;
    room.hordePhase = 'active';
    room.intermissionEndsAt = null;
    room.enemies.clear();
    const count = enemyCountForHorde(horde, room.clients.size);
    const voltSpawnSlots = [240, 904, 320, 824];
    for (let index = 0; index < count; index++) {
      const type = enemyTypeForHorde(horde, random);
      const leftmostX = 240;
      const rightmostX = 1010;
      const spacing = (rightmostX - leftmostX) / Math.max(1, count - 1);
      const x = type === 'volt'
        ? voltSpawnSlots[index % voltSpawnSlots.length]
        : count === 1
          ? 564
          : leftmostX + spacing * index;
      const height = type === 'volt'
        ? 220
        : type === 'watcher'
          ? 60
          : type === 'patrol'
            ? 38
            : 32;
      const enemy = {
        id: `${horde}-${index}-${randomUUID().slice(0, 6)}`,
        type,
        x: Math.round(x),
        y: 928 - height,
        health: type === 'volt' ? 12 : 3,
      };
      room.enemies.set(enemy.id, enemy);
    }
    broadcastHordeState(room);
  }

  function prepareFirstHorde(room) {
    if (room.hordeTimer) return;
    room.hordePhase = 'preparing';
    room.intermissionEndsAt = Date.now() + initialCountdownMs;
    broadcastHordeState(room);
    room.hordeTimer = setTimeout(() => {
      room.hordeTimer = null;
      if (rooms.has(room.id) && room.clients.size > 0) startHorde(room, 1);
    }, initialCountdownMs);
  }

  function finishHorde(room) {
    if (room.horde >= TOTAL_HORDES) {
      room.hordePhase = 'victory';
      room.intermissionEndsAt = null;
      broadcastHordeState(room);
      return;
    }
    room.hordePhase = 'intermission';
    room.intermissionEndsAt = Date.now() + intermissionMs;
    broadcastHordeState(room);
    room.hordeTimer = setTimeout(() => {
      room.hordeTimer = null;
      if (rooms.has(room.id) && room.clients.size > 0) {
        startHorde(room, room.horde + 1);
      }
    }, intermissionMs);
  }

  function leaveRoom(client) {
    if (!client.roomId) return;
    const room = rooms.get(client.roomId);
    client.roomId = null;
    client.state = null;
    if (!room) return;
    room.readyPlayers.delete(client.id);
    room.clients.delete(client.id);
    broadcast(room, { type: 'player_left', playerId: client.id });
    if (room.clients.size === 0) {
      if (room.hordeTimer) clearTimeout(room.hordeTimer);
      rooms.delete(room.id);
    }
    broadcastRoomList();
  }

  function joinRoom(client, room) {
    if (!room || room.clients.size >= MAX_PLAYERS) {
      send(client, { type: 'error', code: 'room_full', message: 'La sala está llena.' });
      return;
    }
    leaveRoom(client);
    client.roomId = room.id;
    const occupiedSlots = new Set(
      [...room.clients.values()].map((candidate) => candidate.spawnIndex),
    );
    client.spawnIndex = PLAYER_NAMES.findIndex(
      (_, index) => !occupiedSlots.has(index),
    );
    client.displayName = PLAYER_NAMES[client.spawnIndex];
    room.clients.set(client.id, client);
    send(client, {
      type: 'room_joined',
      room: roomSummary(room),
      playerId: client.id,
      playerName: client.displayName,
      spawnIndex: client.spawnIndex,
      players: [...room.clients.values()]
        .filter((candidate) => candidate.id !== client.id)
        .map((candidate) => ({
          id: candidate.id,
          name: candidate.displayName,
          spawnIndex: candidate.spawnIndex,
          state: candidate.state,
        })),
      horde: hordeState(room),
    });
    broadcast(room, {
      type: 'player_joined',
      player: {
        id: client.id,
        name: client.displayName,
        spawnIndex: client.spawnIndex,
      },
    }, client.id);
    broadcastRoomList();
  }

  function handleMessage(client, rawMessage) {
    if (rawMessage.length > 4096) return;
    let message;
    try {
      message = JSON.parse(rawMessage.toString());
    } catch {
      send(client, { type: 'error', code: 'invalid_json', message: 'Mensaje inválido.' });
      return;
    }
    switch (message.type) {
      case 'hello':
        client.name = cleanText(message.name, `Jugador ${client.id.slice(0, 4)}`);
        send(client, { type: 'welcome', playerId: client.id, name: client.name });
        send(client, { type: 'rooms', rooms: availableRooms() });
        break;
      case 'list_rooms':
        send(client, { type: 'rooms', rooms: availableRooms() });
        break;
      case 'create_room': {
        const room = {
          id: randomUUID().slice(0, 8),
          name: cleanText(message.name, `Sala de ${client.name}`, 32),
          clients: new Map(),
          readyPlayers: new Set(),
          enemies: new Map(),
          horde: 0,
          hordePhase: 'waiting',
          intermissionEndsAt: null,
          hordeTimer: null,
        };
        rooms.set(room.id, room);
        joinRoom(client, room);
        break;
      }
      case 'join_room':
        joinRoom(client, rooms.get(String(message.roomId || '')));
        break;
      case 'leave_room':
        leaveRoom(client);
        send(client, { type: 'room_left' });
        break;
      case 'arena_ready': {
        const room = rooms.get(client.roomId);
        if (!room) return;
        room.readyPlayers.add(client.id);
        if (room.hordePhase === 'waiting' && room.horde === 0) {
          prepareFirstHorde(room);
        } else {
          send(client, hordeState(room));
        }
        break;
      }
      case 'enemy_hit': {
        const room = rooms.get(client.roomId);
        if (!room || room.hordePhase !== 'active') return;
        const enemy = room.enemies.get(String(message.enemyId || ''));
        if (!enemy || enemy.health <= 0) return;
        const now = Date.now();
        const previousHit = client.enemyHits.get(enemy.id) || 0;
        if (now - previousHit < hitCooldownMs) return;
        client.enemyHits.set(enemy.id, now);
        enemy.health = Math.max(0, enemy.health - 1);
        broadcastHordeState(room);
        if ([...room.enemies.values()].every((candidate) => candidate.health <= 0)) {
          finishHorde(room);
        }
        break;
      }
      case 'player_state': {
        const room = rooms.get(client.roomId);
        if (!room) return;
        const x = Number(message.x);
        const y = Number(message.y);
        if (!Number.isFinite(x) || !Number.isFinite(y)) return;
        client.state = {
          x: Math.max(-100, Math.min(1380, x)),
          y: Math.max(-100, Math.min(1200, y)),
          facing: message.facing === -1 ? -1 : 1,
          animation: allowedAnimations.has(message.animation) ? message.animation : 'idle',
        };
        broadcast(room, {
          type: 'player_state',
          playerId: client.id,
          name: client.displayName,
          ...client.state,
        }, client.id);
        break;
      }
      default:
        send(client, { type: 'error', code: 'unknown_message', message: 'Acción desconocida.' });
    }
  }

  websocketServer.on('connection', (ws) => {
    const client = {
      id: randomUUID(),
      name: 'Jugador',
      displayName: null,
      roomId: null,
      spawnIndex: 0,
      state: null,
      enemyHits: new Map(),
      alive: true,
      ws,
    };
    clients.set(client.id, client);
    ws.on('pong', () => { client.alive = true; });
    ws.on('message', (message) => handleMessage(client, message));
    ws.on('close', () => {
      leaveRoom(client);
      clients.delete(client.id);
      broadcastRoomList();
    });
  });

  const heartbeat = setInterval(() => {
    for (const client of clients.values()) {
      if (!client.alive) {
        client.ws.terminate();
        continue;
      }
      client.alive = false;
      client.ws.ping();
    }
  }, 30000);

  return new Promise((resolve) => {
    httpServer.listen(port, '0.0.0.0', () => {
      const address = httpServer.address();
      resolve({
        port: typeof address === 'object' && address ? address.port : port,
        rooms,
        clients,
        close: () => new Promise((done) => {
          clearInterval(heartbeat);
          for (const room of rooms.values()) {
            if (room.hordeTimer) clearTimeout(room.hordeTimer);
          }
          for (const client of clients.values()) client.ws.close();
          websocketServer.close(() => httpServer.close(done));
        }),
      });
    });
  });
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const server = await createMultiplayerServer();
  console.log(`Sistema Caído multiplayer listening on 0.0.0.0:${server.port}`);
}
