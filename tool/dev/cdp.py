"""Evalúa JavaScript en el WebView del mapa por el protocolo de depuración de Chrome (sin dependencias).

Uso:
  adb forward tcp:9333 localabstract:webview_devtools_remote_$(adb shell pidof com.cresta.cresta)
  python3 tool/dev/cdp.py 'window.cresta.jumpTo(-98.64, 19.15, 14); "ok"'

Acepta promesas (async): útil para mover el mapa, esperar a que carguen los mosaicos y llamar snapLeg.
"""
import base64, json, os, socket, struct, sys, urllib.request

pages = json.load(urllib.request.urlopen('http://127.0.0.1:9333/json'))
url = next(p['webSocketDebuggerUrl'] for p in pages if p['type'] == 'page')
path = url.split('9333', 1)[1]

s = socket.create_connection(('127.0.0.1', 9333), timeout=30)
key = base64.b64encode(os.urandom(16)).decode()
s.sendall((f'GET {path} HTTP/1.1\r\nHost: 127.0.0.1:9333\r\nUpgrade: websocket\r\n'
           f'Connection: Upgrade\r\nSec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n').encode())
buf = b''
while b'\r\n\r\n' not in buf:
    buf += s.recv(4096)
rest = buf.split(b'\r\n\r\n', 1)[1]


def send(obj):
    data = json.dumps(obj).encode()
    mask = os.urandom(4)
    head = bytes([0x81])
    n = len(data)
    if n < 126:
        head += bytes([0x80 | n])
    elif n < 65536:
        head += bytes([0x80 | 126]) + struct.pack('>H', n)
    else:
        head += bytes([0x80 | 127]) + struct.pack('>Q', n)
    s.sendall(head + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(data)))


def recv_exact(n):
    global rest
    while len(rest) < n:
        rest += s.recv(65536)
    out, rest = rest[:n], rest[n:]
    return out


def recv():
    msg = b''
    while True:
        b1, b2 = recv_exact(2)
        n = b2 & 0x7F
        if n == 126:
            n = struct.unpack('>H', recv_exact(2))[0]
        elif n == 127:
            n = struct.unpack('>Q', recv_exact(8))[0]
        msg += recv_exact(n)
        if b1 & 0x80:
            return json.loads(msg)


send({'id': 1, 'method': 'Runtime.evaluate',
      'params': {'expression': sys.argv[1], 'returnByValue': True, 'awaitPromise': True}})
while True:
    m = recv()
    if m.get('id') == 1:
        r = m['result']
        print(json.dumps(r.get('exceptionDetails') or r['result'].get('value'), ensure_ascii=False)[:4000])
        break
