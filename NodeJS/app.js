const WebSocket = require('ws');
const url = require('url');

const wss = new WebSocket.Server({ port: 8080 }, () => {
    console.log("Signaling server is now listening on port 8080")
});
const rooms = {};
// Broadcast to all.
wss.sendAll = (ws, data) => {
    wss.clients.forEach((client) => {
        if (client !== ws && client.readyState === WebSocket.OPEN) {
            client.send(data);
        }
    });
};
// Broadcast to all with me.
wss.sendAllWithMe = (data) => {
    wss.clients.forEach((client) => {
        if (client.readyState === WebSocket.OPEN) {
            client.send(data);
        }
    });
};
wss.sendToUser = function (toUserId, data) {
    wss.clients.forEach(x => { if(x.userId == toUserId) x.send(data) });
}

wss.sendToRoom = function (ws, room, data) {
    if(rooms[room]) Object.values(rooms[room]).forEach((sock) => { if(ws != sock) { sock.send(data) } });
    console.log(`send data to ${room}`)
}

wss.sendToRoomWithMe = function (room, data) {
    if(rooms[room]) { Object.entries(rooms[room]).forEach(([, sock]) => sock.send(data)); }
    console.log(`send data to ${room}`)
}

wss.leaveRoom = function (ws, room) {
    // not present: do nothing
    if (!rooms[room][ws.userId]) return;

    // if the one exiting is the last one, destroy the room
    if (Object.keys(rooms[room]).length === 1) delete rooms[room];
    // otherwise simply leave the room
    else delete rooms[room][ws.userId];
    // wss.sendToRoom(ws, room, wss.parseToBuffer({ payload: { message: "Success", id: ws.userId, resultCode: 1 }, type: "Leave" }))
    console.log(`${ws.userId} leave ${room}`)
}

wss.joinToRoom = function (ws, room) {
    if (!rooms[room]) rooms[room] = {}; // create the room
    if (!rooms[room][ws.userId]) rooms[room][ws.userId] = ws; // join the room
    const clientsInRoom =  { clients: Object.entries(rooms[room]).map(([, sock]) => sock.userId), room: room };
    console.log(`${ws.userId} joined ${room}`)
    wss.sendToRoomWithMe(room, wss.parseToBuffer({ payload: { data: clientsInRoom, message: "Success", id: ws.userId, resultCode: 1 }, type: "Join" }))
}


wss.getUniqueID = function () {
    function s4() {
        return Math.floor((1 + Math.random()) * 0x10000).toString(16).substring(1);
    }
    return s4() + s4() + '-' + s4();
};

wss.parseToBuffer = function (data) {
    return Buffer.from(JSON.stringify(data))
}

wss.on('connection', (ws, req) => {
    console.log(`Client connected. Total connected clients: ${wss.clients.size}`)
    const parameters = url.parse(req.url, true);
    ws.userId = parameters.query.userId;
    const clientsConnected = { clients: Array.from(wss.clients).map(x => x.userId) };
    wss.sendAllWithMe(wss.parseToBuffer({ payload: { data: clientsConnected, message: "Success", id: ws.userId, resultCode: 1 }, type: "ClientsConnected" }))

    ws.on("message", data => {
        const { message, meta, room } = JSON.parse(data.toString());
        console.log(meta);
        console.log(message);

        if (meta === "join") {
            wss.joinToRoom(ws, room)
        }   
        else if (meta === "leave") {
            wss.leave(room, ws.userId);
        }
        else if (meta === "sendRoom") {
            wss.sendToRoom(ws, room, wss.parseToBuffer(message))
        }
        else if (meta === "send") {
            wss.sendToUser(room, wss.parseToBuffer(message))
        }
    });

    ws.on("close", () => {
        // for each room, remove the closed socket
        Object.keys(rooms).forEach(room => {
            wss.leaveRoom(ws, room)
        });
        wss.sendAll(ws, wss.parseToBuffer({ payload: { message: "Success", id: ws.userId, resultCode: 1 }, type: "ClientsDisconnected" }))
        console.log(`${ws.userId} disconnected`)
        
    });
});