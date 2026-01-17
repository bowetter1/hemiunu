const WebSocket = require('ws');

const ws = new WebSocket('ws://localhost:8000/ws');

ws.on('error', (error) => {
  console.log('ERROR:', error.message);
  process.exit(1);
});

ws.on('open', () => {
  console.log('TEST 2a - WebSocket handshake: PASSED');

  // Test init
  ws.send(JSON.stringify({type: 'init', user_id: 'test123'}));
});

let messageCount = 0;
ws.on('message', (data) => {
  messageCount++;
  const msg = JSON.parse(data.toString());

  if (messageCount === 1) {
    // Response to init
    if (msg.type === 'state_sync') {
      console.log('TEST 2b - Init (state_sync): PASSED');
      console.log('  - Total blocks:', msg.data?.stats?.total_blocks);
      console.log('  - Online players:', msg.data?.stats?.online_players);
      console.log('  - User stone:', msg.data?.user_resources?.stone);

      // Test mine_stone
      ws.send(JSON.stringify({type: 'mine_stone', user_id: 'test123'}));
    } else {
      console.log('TEST 2b - Init: FAILED - Expected state_sync, got:', msg.type);
    }
  } else if (messageCount === 2) {
    // Response to mine_stone
    if (msg.type === 'state_sync') {
      console.log('TEST 3 - Mine stone: PASSED');
      console.log('  - Stone after mining:', msg.data?.user_resources?.stone);

      // Test place_block
      ws.send(JSON.stringify({
        type: 'place_block',
        user_id: 'test123',
        data: {x: 5, y: 1, z: 5, type: 'limestone'}
      }));
    } else {
      console.log('TEST 3 - Mine stone: FAILED');
    }
  } else if (messageCount === 3) {
    // Response to place_block (should be block_placed broadcast)
    if (msg.type === 'block_placed') {
      console.log('TEST 4a - Place block (broadcast): PASSED');
      console.log('  - Block placed at:', msg.data?.x, msg.data?.y, msg.data?.z);
    } else if (msg.type === 'state_sync') {
      console.log('TEST 4 - Place block: PASSED (state_sync received)');
      console.log('  - Stone after placing:', msg.data?.user_resources?.stone);
      console.log('  - Total blocks:', msg.data?.stats?.total_blocks);
      ws.close();
    }
  } else if (messageCount === 4) {
    // state_sync after block_placed
    if (msg.type === 'state_sync') {
      console.log('TEST 4b - Place block (state_sync): PASSED');
      console.log('  - Stone after placing:', msg.data?.user_resources?.stone);
      console.log('  - Total blocks:', msg.data?.stats?.total_blocks);
    }
    ws.close();
  }
});

ws.on('close', () => {
  console.log('\n=== All tests completed ===');
  process.exit(0);
});

// Timeout after 10 seconds
setTimeout(() => {
  console.log('TIMEOUT: Tests did not complete in time');
  process.exit(1);
}, 10000);
