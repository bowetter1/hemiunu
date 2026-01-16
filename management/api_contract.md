# API Contract: WebSocket Protocol (v1.0)

## Message Structure
All messages are JSON objects with a mandatory `"type"` field.

---

### 1. Server -> Client: `state_sync`
Sent immediately upon successful WebSocket connection.
```json
{
  "type": "state_sync",
  "data": {
    "pyramid": [
      {"x": 0, "y": 0, "z": 0, "type": "granite"},
      {"x": 1, "y": 0, "z": 0, "type": "limestone"}
    ],
    "stats": {
      "total_blocks": 2,
      "online_players": 5
    },
    "user_resources": {
      "stone": 10
    }
  }
}
```

### 2. Server -> Client: `block_placed`
Broadcast to all connected clients when a block is successfully added.
```json
{
  "type": "block_placed",
  "data": {
    "x": 0,
    "y": 1,
    "z": 0,
    "type": "granite",
    "user_id": "uuid-123"
  }
}
```

### 3. Client -> Server: `mine_stone`
```json
{
  "type": "mine_stone",
  "user_id": "uuid-123"
}
```

### 4. Client -> Server: `place_block`
```json
{
  "type": "place_block",
  "data": {
    "x": 0,
    "y": 1,
    "z": 0,
    "type": "granite"
  }
}
```
