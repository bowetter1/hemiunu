"""
Cargo Panic - A taxi game where passengers freak out when you drift!
Flask server for serving the game.
"""
from flask import Flask, send_from_directory, send_file
import os

app = Flask(__name__, static_folder='.')

@app.route('/')
def index():
    return send_file('index.html')

@app.route('/node_modules/<path:path>')
def serve_node_modules(path):
    return send_from_directory('node_modules', path)

@app.route('/src/<path:path>')
def serve_src(path):
    return send_from_directory('src', path)

@app.route('/assets/<path:path>')
def serve_assets(path):
    return send_from_directory('assets', path)

@app.route('/<path:path>')
def serve_static(path):
    return send_from_directory('.', path)

if __name__ == '__main__':
    print("🚕 Cargo Panic server running at http://localhost:8000")
    app.run(host='0.0.0.0', port=8000, debug=True)
