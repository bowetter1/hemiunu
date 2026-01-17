import socket
import json
import base64
import os

def websocket_test():
    host = 'localhost'
    port = 8000
    path = '/ws'

    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(5)

    try:
        sock.connect((host, port))

        key = base64.b64encode(os.urandom(16)).decode('utf-8')
        handshake = f"GET {path} HTTP/1.1\r\n"
        handshake += f"Host: {host}:{port}\r\n"
        handshake += "Upgrade: websocket\r\n"
        handshake += "Connection: Upgrade\r\n"
        handshake += f"Sec-WebSocket-Key: {key}\r\n"
        handshake += "Sec-WebSocket-Version: 13\r\n\r\n"

        sock.send(handshake.encode())
        response = sock.recv(1024).decode('utf-8')

        if '101' in response:
            print("TEST 2a - WebSocket handshake: PASSED")

            def send_ws_message(sock, message):
                msg_bytes = message.encode('utf-8')
                length = len(msg_bytes)
                mask = os.urandom(4)
                frame = bytearray()
                frame.append(0x81)
                if length <= 125:
                    frame.append(0x80 | length)
                elif length <= 65535:
                    frame.append(0x80 | 126)
                    frame.extend(length.to_bytes(2, 'big'))
                frame.extend(mask)
                masked = bytearray(b ^ mask[i % 4] for i, b in enumerate(msg_bytes))
                frame.extend(masked)
                sock.send(bytes(frame))

            def recv_ws_message(sock):
                data = sock.recv(2)
                if len(data) < 2:
                    return None
                length = data[1] & 0x7f
                if length == 126:
                    length = int.from_bytes(sock.recv(2), 'big')
                elif length == 127:
                    length = int.from_bytes(sock.recv(8), 'big')
                payload = sock.recv(length)
                return payload.decode('utf-8')

            # Test 2b: Init
            send_ws_message(sock, '{"type": "init", "user_id": "test123"}')
            response = recv_ws_message(sock)
            if response:
                data = json.loads(response)
                if data.get('type') == 'state_sync':
                    print("TEST 2b - Init (state_sync): PASSED")
                    state = data.get('data', {})
                    print(f"  - Total blocks: {state.get('stats', {}).get('total_blocks', 'N/A')}")
                    print(f"  - Online players: {state.get('stats', {}).get('online_players', 'N/A')}")
                    print(f"  - User stone: {state.get('user_resources', {}).get('stone', 'N/A')}")
                else:
                    print(f"TEST 2b - Init: FAILED - Expected state_sync, got: {data.get('type')}")
            else:
                print("TEST 2b - Init: FAILED - No response")

            # Test 3: Mine stone
            send_ws_message(sock, '{"type": "mine_stone", "user_id": "test123"}')
            response = recv_ws_message(sock)
            if response:
                data = json.loads(response)
                if data.get('type') == 'state_sync':
                    new_stone = data.get('data', {}).get('user_resources', {}).get('stone', 0)
                    print(f"TEST 3 - Mine stone: PASSED")
                    print(f"  - Stone after mining: {new_stone}")
                else:
                    print(f"TEST 3 - Mine stone: FAILED - Unexpected response type: {data.get('type')}")
            else:
                print("TEST 3 - Mine stone: FAILED - No response")

            # Test 4: Place block - Note: x,y,z should be in "data" object according to handler
            send_ws_message(sock, '{"type": "place_block", "user_id": "test123", "data": {"x": 5, "y": 1, "z": 5, "type": "limestone"}}')
            response = recv_ws_message(sock)
            if response:
                data = json.loads(response)
                print(f"TEST 4a - Place block (broadcast): Response type: {data.get('type')}")
                if data.get('type') == 'block_placed':
                    print(f"  - Block placed at: ({data.get('data', {}).get('x')}, {data.get('data', {}).get('y')}, {data.get('data', {}).get('z')})")
                    # Should also receive state_sync after broadcast
                    response2 = recv_ws_message(sock)
                    if response2:
                        data2 = json.loads(response2)
                        if data2.get('type') == 'state_sync':
                            new_stone = data2.get('data', {}).get('user_resources', {}).get('stone', 0)
                            total_blocks = data2.get('data', {}).get('stats', {}).get('total_blocks', 0)
                            print(f"TEST 4b - Place block (state_sync): PASSED")
                            print(f"  - Stone after placing: {new_stone}")
                            print(f"  - Total blocks: {total_blocks}")
                else:
                    print(f"  - Response: {data}")
            else:
                print("TEST 4 - Place block: FAILED - No response")

        else:
            print(f"TEST 2a - WebSocket handshake: FAILED")
            print(f"  - Response: {response[:200]}")

    except socket.timeout:
        print("ERROR: Connection timeout")
    except Exception as e:
        print(f"ERROR: {e}")
    finally:
        sock.close()

if __name__ == "__main__":
    websocket_test()
