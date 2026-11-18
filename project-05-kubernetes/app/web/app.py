from flask import Flask, jsonify
import socket
import requests
import os

app = Flask(__name__)
API_URL = os.environ.get("API_URL", "http://api-service:5000")

@app.route("/")
def index():
    try:
        resp = requests.get(f"{API_URL}/", timeout=3)
        api_data = resp.json()
    except Exception as e:
        api_data = {"error": str(e)}

    return jsonify({
        "service": "web",
        "pod_hostname": socket.gethostname(),
        "called_api_at": API_URL,
        "api_response": api_data
    })

@app.route("/health")
def health():
    return jsonify({"status": "healthy"}), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
