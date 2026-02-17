#!/usr/bin/env python3

import http.server
import socketserver
import json
import subprocess
import os
import sys
import time
import threading

PORT = 3000
credentials = None
bore_process = None


class Handler(http.server.SimpleHTTPRequestHandler):
    def do_POST(self):
        global credentials

        if self.path == "/connect":
            content_length = int(self.headers["Content-Length"])
            post_data = self.rfile.read(content_length)

            try:
                data = json.loads(post_data.decode("utf-8"))
                credentials = data
                print(f"Received credentials: {data}")

                self.send_response(200)
                self.send_header("Content-type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"status": "ok"}).encode())

                # Shutdown after receiving
                threading.Timer(2, shutdown).start()

            except Exception as e:
                self.send_response(500)
                self.end_headers()
                print(f"Error: {e}")
        else:
            self.send_response(404)
            self.end_headers()

    def do_GET(self):
        if self.path == "/status":
            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()

            if credentials:
                response = {"status": "ready", "credentials": credentials}
            else:
                response = {"status": "waiting"}

            self.wfile.write(json.dumps(response).encode())
        else:
            self.send_response(200)
            self.send_header("Content-type", "text/html")
            self.end_headers()
            self.wfile.write(b"OpenTunnel Webhook Running")


def start_bore():
    global bore_process

    try:
        subprocess.run(["bore", "--version"], capture_output=True)
    except FileNotFoundError:
        print("Installing bore...")
        try:
            result = subprocess.run(
                ["curl", "-fsSL", "https://getbore.io"], capture_output=True, text=True
            )
            subprocess.run(["bash", "-c", result.stdout], check=True)
        except:
            print("Failed to install bore automatically")
            return None

    print("Starting bore tunnel...")
    try:
        bore_process = subprocess.Popen(
            ["bore", "local", str(PORT), "--to", "bore.pub"],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )

        # Wait for bore to start
        port = None
        for _ in range(30):
            time.sleep(1)
            if bore_process.poll() is not None:
                break
            try:
                with open(os.path.expanduser("~/.bore_local"), "r") as f:
                    content = f.read()
                    import re

                    match = re.search(r"bore\.pub:(\d+)", content)
                    if match:
                        port = match.group(1)
                        break
            except:
                pass

        return port
    except Exception as e:
        print(f"Error starting bore: {e}")
        return None


def shutdown():
    global bore_process
    if bore_process:
        bore_process.terminate()
    httpd.shutdown()


if __name__ == "__main__":
    bore_port = start_bore()

    if bore_port:
        print(f"\n{'=' * 40}")
        print("Server running! Share this port:")
        print(f"bore.pub:{bore_port}")
        print(f"{'=' * 40}\n")
    else:
        print("Warning: bore not available, running on localhost only")
        print("Note: Remote must be able to reach this machine directly")

    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        httpd.serve_forever()
