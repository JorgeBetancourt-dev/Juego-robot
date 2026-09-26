# Sistema Caído

Prototipo móvil 2D desarrollado con Flutter y Flame. Esta primera base implementa la separación entre interfaz Flutter, dominio, adaptadores de Flame y persistencia, utilizando únicamente elementos visuales generados por código.

## Requisitos

- Flutter estable compatible con Dart 3.12 o superior.
- Android SDK configurado.
- Un dispositivo o emulador Android en orientación horizontal.

## Ejecución

```powershell
flutter pub get
flutter run
```

Para ejecutar el modo multijugador contra el servidor local:

```powershell
cd server
npm install
npm start
```

En otra terminal, define la dirección alcanzable desde el dispositivo:

```powershell
flutter run --dart-define=MULTIPLAYER_URL=ws://DIRECCION_DEL_SERVIDOR:8080/ws
```

En una compilación pública se debe usar `wss://`. El servidor mantiene salas
temporales y públicas de hasta cuatro jugadores; no modifica el guardado de la
campaña.

La versión de prueba usa por defecto el servicio gratuito:
`wss://sistema-caido-multiplayer.onrender.com/ws`. Se puede sustituir mediante
`MULTIPLAYER_URL` para desarrollo local. Render puede suspender la instancia
después de un periodo sin actividad, por lo que la primera conexión puede tardar
aproximadamente un minuto.

## Controles

- Teclado: `A/D` o flechas para mover, `Space` para saltar, `J` para atacar, `K` para dash y `Esc` para pausar.
- Táctil: dirección a la izquierda; ataque, dash y salto a la derecha. Los botones admiten pulsaciones simultáneas.

## Arquitectura

- `lib/app`: navegación, pantallas, overlays y controles táctiles.
- `lib/domain`: configuración, entrada semántica, movimiento, progreso, sesión y contratos de persistencia.
- `lib/game`: juego, mundo y representación provisional con Flame.
- `lib/infrastructure`: implementación local del guardado versionado.
- `server`: servicio WebSocket de salas y retransmisión del estado multijugador.

La lógica de movimiento usa colisiones AABB y valores centralizados en `GameplayConfig`. No depende del tamaño de imágenes ni de rutas de assets, por lo que los placeholders podrán sustituirse por sprites sin reescribir el motor.

## Estado de implementación

Completado en la base actual:

- Arranque inmersivo en landscape.
- Menú de inicio, continuación, nueva partida y playground.
- `GameSession`, `GameProgress` versionado y guardado local robusto.
- Entrada semántica multi touch y teclado.
- Sala P01 provisional con cámara fija, carrera, salto variable, coyote time, jump buffer, dash, wall slide, wall jump, doble salto y golpe descendente.
- Plataformas sólidas, unidireccionales y una plataforma móvil que transporta al jugador.
- Ataque con fases, hitbox independiente, vida, daño, invulnerabilidad, knockback, muerte y respawn.
- Patrol Unit provisional con patrulla, contacto, vida y recepción de ataques.
- Checkpoint funcional y HUD técnico con estado y vida.
- Catálogo declarativo conectado de diez salas P01 a P10.
- Transiciones laterales, puertas por requisito, permiso, interruptor persistente y secreto.
- Adquisición persistente de Dash, Wall jump, Golpe descendente y Doble salto durante el recorrido.
- Watcher con telegraph temporal y proyectiles, y Drone con patrulla aérea.
- Suelo rompible persistente activado por golpe descendente.
- VOLT con barra de vida, tres patrones anticipados, dos fases, ventanas de sobrecarga, arena bloqueada y recompensa Dash persistente.
- Valores iniciales de física centralizados y placeholders dibujados por código.
- Navegador de salas públicas, creación y entrada a partidas de hasta cuatro
  jugadores, con posiciones y animaciones sincronizadas por WebSocket.

Siguientes fases: selector y panel de debug, opciones de controles, pruebas de widgets e integración y ajuste en dispositivo físico.
