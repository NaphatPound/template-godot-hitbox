#!/usr/bin/env python3
"""
Local web server for Godot 4 web export.
Sets required COOP/COEP headers for SharedArrayBuffer (needed by Godot WebAssembly).
Usage: python serve_web.py
Then open: http://localhost:8080
"""
import http.server
import os
import threading

PORT = 8000
DIRECTORY = os.path.join(os.path.dirname(__file__), "export", "web")

class GodotHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def end_headers(self):
        # Required for Godot 4 WebAssembly / SharedArrayBuffer
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def log_message(self, format, *args):
        print(f"[SERVER] {self.address_string()} - {format % args}")


class ThreadingServer(http.server.ThreadingHTTPServer):
    pass

if __name__ == "__main__":
    os.chdir(DIRECTORY)
    with ThreadingServer(("", PORT), GodotHandler) as httpd:
        print(f"[SERVER] Boss Rush serving at http://localhost:{PORT}")
        print(f"[SERVER] Directory: {DIRECTORY}")
        print("[SERVER] Press Ctrl+C to stop.")
        httpd.serve_forever()
