from flask import Flask, jsonify
from datetime import datetime

app = Flask(__name__)

@app.route("/")
def home():
    return jsonify({
        "status": "running",
        "message": "CI/CD Pipeline Demo",
        "version": "1.0.0",
        "deployed_at": datetime.now().isoformat(),
        "features": [
            "Docker containerized",
            "GitHub Actions CI/CD",
            "Automated testing",
            "Deployed to EC2"
        ]
    })

@app.route("/health")
def health():
    return jsonify({"status": "healthy"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
    