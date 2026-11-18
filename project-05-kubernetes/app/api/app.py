from flask import Flask, jsonify
import socket
import time

app = Flask(__name__)
start_time = time.time()

@app.route("/")
def index():
    return jsonify({
        "service": "api",
        "message": "Hello from the backend API",
        "pod_hostname": socket.gethostname(),
        "uptime_seconds": round(time.time() - start_time, 1)
    })

@app.route("/health")
def health():
    return jsonify({"status": "healthy"}), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
