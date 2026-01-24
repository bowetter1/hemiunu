"""
Neon Drift - A zen driving game where your drifts paint glowing trails
Simple Python server to serve the game files
"""

from http.server import HTTPServer, SimpleHTTPRequestHandler
import os

class GameHandler(SimpleHTTPRequestHandler):
    """Custom handler with proper MIME types"""
    
    extensions_map = {
        '': 'application/octet-stream',
        '.html': 'text/html',
        '.css': 'text/css',
        '.js': 'application/javascript',
        '.json': 'application/json',
        '.png': 'image/png',
        '.jpg': 'image/jpeg',
        '.gif': 'image/gif',
        '.svg': 'image/svg+xml',
        '.ico': 'image/x-icon',
        '.mp3': 'audio/mpeg',
        '.wav': 'audio/wav',
        '.ogg': 'audio/ogg',
    }

def run_server(port=8000):
    """Start the game server"""
    server_address = ('', port)
    httpd = HTTPServer(server_address, GameHandler)
    print(f"""
╔══════════════════════════════════════════════════════════╗
║                     NEON DRIFT                           ║
║           Your drifts paint the night                    ║
╠══════════════════════════════════════════════════════════╣
║  Server running at: http://localhost:{port}               ║
║  Press Ctrl+C to stop                                    ║
╚══════════════════════════════════════════════════════════╝
    """)
    httpd.serve_forever()

if __name__ == '__main__':
    run_server()
