import assert from 'node:assert/strict';
import WebSocket from 'ws';

const endpoint = process.env.COLLAB_URL || 'ws://localhost:8787';
const clients = [];
const state = {version:1,currentMap:'pc',mode:'attack',drawings:{pc:[]},callouts:{pc:[]},layers:{},stages:{}};

function client() {
  const socket = new WebSocket(endpoint);
  clients.push(socket);
  return new Promise((resolve, reject) => {
    socket.once('open', () => resolve(socket));
    socket.once('error', reject);
  });
}

function next(socket, type, timeout = 3000) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`Timed out waiting for ${type}`)), timeout);
    const listener = data => {
      const message = JSON.parse(data.toString());
      if (message.type !== type) return;
      clearTimeout(timer);
      socket.off('message', listener);
      resolve(message);
    };
    socket.on('message', listener);
  });
}

try {
  const owner = await client();
  owner.send(JSON.stringify({type:'create',name:'房主',state}));
  const created = await next(owner, 'joined');
  assert.match(created.roomId, /^JDI-[A-F0-9]{8}$/);
  assert.equal(created.role, 'owner');

  const editor = await client();
  editor.send(JSON.stringify({type:'join',roomId:created.roomId,name:'编辑者',role:'editor'}));
  const editorJoined = await next(editor, 'joined');
  assert.equal(editorJoined.role, 'editor');

  const observer = await client();
  observer.send(JSON.stringify({type:'join',roomId:created.roomId,name:'观察者',role:'observer'}));
  const observerJoined = await next(observer, 'joined');
  assert.equal(observerJoined.role, 'observer');

  const operation = {type:'object.upsert',payload:{mapId:'pc',object:{id:'test-marker',type:'marker',points:[{x:100,y:200}],color:'#d5f249',width:5}}};
  const receivedOperation = next(editor, 'operation');
  owner.send(JSON.stringify({type:'operation',operation}));
  assert.deepEqual((await receivedOperation).operation, operation);

  const rejected = next(observer, 'error');
  observer.send(JSON.stringify({type:'operation',operation:{...operation,payload:{...operation.payload,object:{...operation.payload.object,id:'blocked'}}}}));
  assert.match((await rejected).message, /观察者/);

  const late = await client();
  late.send(JSON.stringify({type:'join',roomId:created.roomId,name:'后来者',role:'editor'}));
  const lateJoined = await next(late, 'joined');
  assert.equal(lateJoined.snapshot.drawings.pc.some(item => item.id === 'test-marker'), true);
  console.log(`Collaboration test passed for ${created.roomId}`);
} finally {
  clients.forEach(socket => socket.close());
}
