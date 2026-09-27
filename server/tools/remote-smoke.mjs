import WebSocket from 'ws';

const endpoint = process.argv[2];
if (!endpoint) throw new Error('Uso: node tools/remote-smoke.mjs wss://servidor/ws');

function connect(name) {
  return new Promise((resolve, reject) => {
    const socket = new WebSocket(endpoint);
    const messages = [];
    const waiters = [];
    const waitFor = (predicate) => new Promise((done, fail) => {
      const existing = messages.find(predicate);
      if (existing) return done(existing);
      const timer = setTimeout(() => fail(new Error('Tiempo de espera agotado')), 15000);
      waiters.push({
        predicate,
        done: (message) => {
          clearTimeout(timer);
          done(message);
        },
      });
    });
    socket.on('error', reject);
    socket.on('message', (raw) => {
      const message = JSON.parse(raw.toString());
      messages.push(message);
      for (const waiter of [...waiters]) {
        if (!waiter.predicate(message)) continue;
        waiters.splice(waiters.indexOf(waiter), 1);
        waiter.done(message);
      }
    });
    socket.on('open', async () => {
      socket.send(JSON.stringify({ type: 'hello', name }));
      await waitFor((message) => message.type === 'welcome');
      resolve({ socket, waitFor });
    });
  });
}

const first = await connect('Prueba 1');
const second = await connect('Prueba 2');
try {
  first.socket.send(JSON.stringify({ type: 'create_room', name: 'Prueba automática' }));
  const joined = await first.waitFor((message) => message.type === 'room_joined');
  if (joined.playerName !== 'M-0-Rojo') {
    throw new Error(`El primer jugador recibió el nombre ${joined.playerName}.`);
  }
  second.socket.send(JSON.stringify({ type: 'join_room', roomId: joined.room.id }));
  const secondJoined = await second.waitFor((message) => message.type === 'room_joined');
  if (secondJoined.playerName !== 'M-0-Verde') {
    throw new Error(`El segundo jugador recibió el nombre ${secondJoined.playerName}.`);
  }
  second.socket.send(JSON.stringify({
    type: 'player_state',
    x: 320,
    y: 640,
    facing: 1,
    animation: 'run',
  }));
  const state = await first.waitFor((message) => message.type === 'player_state');
  if (state.x !== 320 || state.animation !== 'run' || state.name !== 'M-0-Verde') {
    throw new Error('El estado recibido no coincide.');
  }
  first.socket.send(JSON.stringify({ type: 'arena_ready' }));
  const horde = await first.waitFor(
    (message) => message.type === 'horde_state' && message.phase === 'active',
  );
  if (horde.horde !== 1 || horde.enemies.length !== 4) {
    throw new Error('La primera horda no coincide con dos jugadores.');
  }
  if (horde.enemies.some((enemy) => enemy.type === 'volt')) {
    throw new Error('VOLT apareció antes de la horda final.');
  }
  console.log(
    `OK: sala ${joined.room.id}, dos jugadores y ${horde.enemies.length} enemigos sincronizados.`,
  );
} finally {
  first.socket.close();
  second.socket.close();
}
