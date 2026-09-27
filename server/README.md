# Servidor multijugador de Sistema Caído

Servidor WebSocket temporal para salas públicas de hasta cuatro jugadores.

## Desarrollo local

```powershell
cd server
npm install
npm test
npm start
```

El servicio HTTP escucha en `PORT` (8080 por defecto) y el WebSocket en `/ws`.
Las salas viven en memoria y se eliminan cuando sale el último jugador.

Cada sala ejecuta cinco hordas cooperativas. Las primeras cuatro generan
`jugadores × 2`, `× 3`, `× 4` y `× 5` enemigos aleatorios sin VOLT. La quinta
genera un VOLT por jugador. El servidor conserva la vida compartida de los
enemigos y espera 10 segundos entre hordas.
Antes de la primera horda muestra una preparación sincronizada de 5 segundos.

Prueba contra un despliegue público:

```powershell
node tools/remote-smoke.mjs wss://NOMBRE.onrender.com/ws
```

## Render

El `render.yaml` de la raíz configura un Web Service gratuito. Después de
publicarlo, compila la aplicación con:

```powershell
flutter build apk --release --dart-define=MULTIPLAYER_URL=wss://NOMBRE.onrender.com/ws
```
