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

## Render

El `render.yaml` de la raíz configura un Web Service gratuito. Después de
publicarlo, compila la aplicación con:

```powershell
flutter build apk --release --dart-define=MULTIPLAYER_URL=wss://NOMBRE.onrender.com/ws
```
