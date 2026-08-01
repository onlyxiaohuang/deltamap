import { createServer } from 'node:http';
import { createReadStream, existsSync, mkdirSync, statSync } from 'node:fs';
import { dirname, extname, join, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomBytes, randomUUID } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';
import { WebSocketServer, WebSocket } from 'ws';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..');
const dataDir = resolve(process.env.DELTAMAP_DATA_DIR || join(root, 'server', 'data'));
const port = Number(process.env.PORT || 8787);
const host = process.env.HOST || '0.0.0.0';
const maxMembers = 10;
const colors = ['#d5f249','#42a5ff','#ff5f55','#ffb43b','#b47cff','#56e0cf','#f58bd6','#ffffff','#8dd45c','#ff8d52'];

mkdirSync(dataDir, { recursive: true });
const db = new DatabaseSync(join(dataDir, 'deltamap-collab.sqlite'));
db.exec(`
  PRAGMA journal_mode = WAL;
  CREATE TABLE IF NOT EXISTS rooms (
    id TEXT PRIMARY KEY,
    owner_client_id TEXT NOT NULL,
    snapshot TEXT NOT NULL,
    revision INTEGER NOT NULL DEFAULT 0,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  );
  CREATE TABLE IF NOT EXISTS operations (
    id TEXT PRIMARY KEY,
    room_id TEXT NOT NULL,
    revision INTEGER NOT NULL,
    client_id TEXT NOT NULL,
    operation TEXT NOT NULL,
    created_at INTEGER NOT NULL
  );
  CREATE INDEX IF NOT EXISTS operations_room_revision ON operations(room_id, revision);
`);

const rooms = new Map();
const mime = {'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.json':'application/json; charset=utf-8','.png':'image/png','.jpg':'image/jpeg','.ico':'image/x-icon'};
const httpServer = createServer((request, response) => {
  let pathname;
  try { pathname = decodeURIComponent(new URL(request.url, `http://${request.headers.host}`).pathname); }
  catch { response.writeHead(400).end('Bad request'); return; }
  if (pathname === '/health') { response.writeHead(200, {'Content-Type':'application/json'}).end(JSON.stringify({ok:true,rooms:rooms.size})); return; }
  const target = resolve(root, `.${pathname === '/' ? '/index.html' : pathname}`);
  if (!(target === root || target.startsWith(root + sep)) || !existsSync(target) || !statSync(target).isFile()) { response.writeHead(404).end('Not found'); return; }
  response.writeHead(200, {'Content-Type':mime[extname(target).toLowerCase()] || 'application/octet-stream','Cache-Control':'no-cache'});
  createReadStream(target).pipe(response);
});

function emptyState() { return {version:1,currentMap:'pc',mode:'attack',drawings:{},callouts:{},layers:{},stages:{}}; }
function roomCode() { return `JDI-${randomBytes(4).toString('hex').toUpperCase()}`; }
function cleanName(value) { return String(value || '队员').trim().slice(0, 18) || '队员'; }
function send(client, message) { if (client.socket.readyState === WebSocket.OPEN) client.socket.send(JSON.stringify(message)); }
function publicMembers(room) { return [...room.clients.values()].map(client => ({clientId:client.id,name:client.name,role:client.role,color:client.color})); }
function broadcast(room, message, exceptId = null) { room.clients.forEach(client => { if (client.id !== exceptId) send(client, message); }); }
function presence(room) { broadcast(room, {type:'presence',members:publicMembers(room)}); }
function loadRoom(id) {
  if (rooms.has(id)) return rooms.get(id);
  const row = db.prepare('SELECT * FROM rooms WHERE id = ?').get(id);
  if (!row) return null;
  const room = {id,ownerClientId:row.owner_client_id,snapshot:JSON.parse(row.snapshot),revision:row.revision,clients:new Map()};
  rooms.set(id, room);
  return room;
}
function saveRoom(room) {
  db.prepare('UPDATE rooms SET snapshot = ?, revision = ?, updated_at = ? WHERE id = ?').run(JSON.stringify(room.snapshot), room.revision, Date.now(), room.id);
}
function validMapBucket(state, key, mapId) { if (!state[key]) state[key] = {}; if (!Array.isArray(state[key][mapId])) state[key][mapId] = []; return state[key][mapId]; }
function applyOperation(state, operation) {
  const payload = operation?.payload || {};
  if (operation?.type === 'object.upsert' && payload.object?.id && payload.mapId) {
    const items = validMapBucket(state, 'drawings', payload.mapId), index = items.findIndex(item => item.id === payload.object.id);
    index < 0 ? items.push(payload.object) : items[index] = payload.object;
  } else if (operation?.type === 'object.delete' && payload.id && payload.mapId) {
    state.drawings[payload.mapId] = validMapBucket(state, 'drawings', payload.mapId).filter(item => item.id !== payload.id);
  } else if (operation?.type === 'callout.upsert' && payload.callout?.id && payload.mapId) {
    const items = validMapBucket(state, 'callouts', payload.mapId), index = items.findIndex(item => item.id === payload.callout.id);
    index < 0 ? items.push(payload.callout) : items[index] = payload.callout;
  } else if (operation?.type === 'callout.delete' && payload.id && payload.mapId) {
    state.callouts[payload.mapId] = validMapBucket(state, 'callouts', payload.mapId).filter(item => item.id !== payload.id);
  } else if (operation?.type === 'meta.set') {
    if (payload.layers && typeof payload.layers === 'object') state.layers = payload.layers;
    if (payload.stages && typeof payload.stages === 'object') state.stages = payload.stages;
    if (payload.mode === 'attack' || payload.mode === 'occupy') state.mode = payload.mode;
    if (typeof payload.currentMap === 'string') state.currentMap = payload.currentMap;
  } else return false;
  state.updatedAt = Date.now();
  return true;
}
function joinClient(client, room, requestedRole) {
  if (room.clients.size >= maxMembers) { send(client, {type:'error',message:'房间人数已满'}); return false; }
  client.room = room;
  client.role = client.id === room.ownerClientId ? 'owner' : requestedRole === 'observer' ? 'observer' : 'editor';
  client.color = colors[room.clients.size % colors.length];
  room.clients.set(client.id, client);
  send(client, {type:'joined',roomId:room.id,clientId:client.id,name:client.name,role:client.role,color:client.color,snapshot:room.snapshot,revision:room.revision,members:publicMembers(room)});
  presence(room);
  return true;
}

const wss = new WebSocketServer({ server: httpServer, maxPayload: 16 * 1024 * 1024 });
wss.on('connection', socket => {
  const client = {id:randomUUID(),name:'队员',role:'observer',color:colors[0],room:null,socket,joinAttempts:0};
  socket.on('message', buffer => {
    let message;
    try { message = JSON.parse(buffer.toString()); } catch { send(client,{type:'error',message:'消息格式无效'}); return; }
    if (message.type === 'create') {
      let id; do { id = roomCode(); } while (loadRoom(id));
      client.id = randomUUID(); client.name = cleanName(message.name);
      const snapshot = message.state?.drawings ? message.state : emptyState(), now = Date.now();
      const room = {id,ownerClientId:client.id,snapshot,revision:0,clients:new Map()};
      db.prepare('INSERT INTO rooms(id, owner_client_id, snapshot, revision, created_at, updated_at) VALUES(?,?,?,?,?,?)').run(id, client.id, JSON.stringify(snapshot), 0, now, now);
      rooms.set(id, room); joinClient(client, room, 'owner'); return;
    }
    if (message.type === 'join') {
      client.joinAttempts += 1;
      if (client.joinAttempts > 10) { socket.close(1008, 'Too many join attempts'); return; }
      const id = String(message.roomId || '').trim().toUpperCase(), room = loadRoom(id);
      if (!room) { send(client,{type:'error',message:'房间不存在'}); return; }
      if (message.clientId && message.clientId === room.ownerClientId) client.id = message.clientId;
      client.name = cleanName(message.name); joinClient(client, room, message.role); return;
    }
    const room = client.room;
    if (!room) { send(client,{type:'error',message:'请先加入房间'}); return; }
    if (message.type === 'cursor') {
      const x = Number(message.x), y = Number(message.y);
      if (Number.isFinite(x) && Number.isFinite(y)) broadcast(room,{type:'cursor',clientId:client.id,name:client.name,color:client.color,mapId:String(message.mapId||''),x,y},client.id);
      return;
    }
    if (message.type === 'operation') {
      if (client.role === 'observer') { send(client,{type:'error',message:'观察者不能编辑'}); return; }
      const serialized = JSON.stringify(message.operation);
      if (serialized.length > 2 * 1024 * 1024 || !applyOperation(room.snapshot, message.operation)) { send(client,{type:'error',message:'操作无效'}); return; }
      room.revision += 1;
      const operationId = randomUUID(), now = Date.now();
      db.prepare('INSERT INTO operations(id, room_id, revision, client_id, operation, created_at) VALUES(?,?,?,?,?,?)').run(operationId, room.id, room.revision, client.id, serialized, now);
      saveRoom(room);
      if (room.revision % 100 === 0) db.prepare('DELETE FROM operations WHERE room_id = ? AND revision < ?').run(room.id, Math.max(0, room.revision - 1000));
      broadcast(room,{type:'operation',operationId,revision:room.revision,clientId:client.id,operation:message.operation},client.id);
    }
  });
  socket.on('close', () => { if (!client.room) return; client.room.clients.delete(client.id); presence(client.room); });
});

httpServer.listen(port, host, () => {
  console.log(`DeltaMap collaboration server: http://${host === '0.0.0.0' ? 'localhost' : host}:${port}`);
  console.log(`WebSocket endpoint: ws://${host === '0.0.0.0' ? 'localhost' : host}:${port}`);
  console.log(`SQLite: ${join(dataDir, 'deltamap-collab.sqlite')}`);
});
