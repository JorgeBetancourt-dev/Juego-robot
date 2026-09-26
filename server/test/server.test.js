import assert from 'node:assert/strict';
import { test } from 'node:test';
import WebSocket from 'ws';

import { createMultiplayerServer } from '../src/server.js';

function clientFor(port, name) {
  return new Promise((resolve, reject) => {
    const socket = new WebSocket(`ws://127.0.0.1:${port}/ws`);
    const messages = [];
    const waiters = [];
    socket.on('open', () => socket.send(JSON.stringify({ type: 'hello', name })));
    socket.on('error', reject);
    socket.on('message', (raw) => {
      const message = JSON.parse(raw.toString());
      messages.push(message);
      for (const waiter of [...waiters]) {
        if (waiter.predicate(message)) {
          waiters.splice(waiters.indexOf(waiter), 1);
          waiter.resolve(message);
        }
      }
    });
    const waitFor = (predicate) => new Promise((waitResolve, waitReject) => {
      const existing = messages.find(predicate);
      if (existing) return waitResolve(existing);
      const timer = setTimeout(() => waitReject(new Error('Timeout waiting for message')), 2000);
      waiters.push({
        predicate,
        resolve: (message) => { clearTimeout(timer); waitResolve(message); },
      });
    });
    socket.once('open', async () => {
      await waitFor((message) => message.type === 'welcome');
      resolve({ socket, waitFor });
    });
  });
}

test('creates, lists and caps public rooms at four players', async () => {
  const server = await createMultiplayerServer({ port: 0 });
  const clients = [];
  try {
    const owner = await clientFor(server.port, 'M-0');
    clients.push(owner);
    owner.socket.send(JSON.stringify({ type: 'create_room', name: 'Arena libre' }));
    const joined = await owner.waitFor((message) => message.type === 'room_joined');
    assert.equal(joined.room.playerCount, 1);
    assert.equal(joined.room.maxPlayers, 4);
    assert.equal(joined.playerName, 'M-0-Rojo');

    const expectedNames = ['M-0-Verde', 'M-0-Azul', 'M-0-Amarillo'];
    for (let index = 1; index < 4; index++) {
      const client = await clientFor(server.port, `Jugador ${index + 1}`);
      clients.push(client);
      client.socket.send(JSON.stringify({ type: 'join_room', roomId: joined.room.id }));
      const playerJoined = await client.waitFor(
        (message) => message.type === 'room_joined',
      );
      assert.equal(playerJoined.playerName, expectedNames[index - 1]);
    }

    clients[1].socket.send(JSON.stringify({
      type: 'player_state',
      x: 320,
      y: 640,
      facing: -1,
      animation: 'run',
    }));
    const state = await owner.waitFor((message) => message.type === 'player_state');
    assert.equal(state.x, 320);
    assert.equal(state.animation, 'run');
    assert.equal(state.name, 'M-0-Verde');

    const fifth = await clientFor(server.port, 'Jugador 5');
    clients.push(fifth);
    fifth.socket.send(JSON.stringify({ type: 'join_room', roomId: joined.room.id }));
    const error = await fifth.waitFor((message) => message.code === 'room_full');
    assert.equal(error.message, 'La sala está llena.');
  } finally {
    for (const client of clients) client.socket.close();
    await server.close();
  }
});
