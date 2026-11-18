"""Project 11: Project 3's demo app, served by gunicorn from a signed, digest-pinned image."""
import os
from datetime import datetime, timezone

from flask import Flask, jsonify

app = Flask(__name__)

VERSION = "2.0.0"


@app.route("/")
def home():
    return jsonify({
        "status": "running",
        "message": "Secure supply chain demo",
        "version": VERSION,
        # Set at deploy time from the signed digest, so a caller can check what's running.
        "image_digest": os.environ.get("IMAGE_DIGEST", "unknown"),
        "served_at": datetime.now(timezone.utc).isoformat(),
        "features": [
            "Built once, tested, scanned and signed in CI",
            "Deployed by digest, signature checked first",
            "No SSH: deployed through SSM",
            "Non-root container",
        ],
    })


@app.route("/health")
def health():
    return jsonify({"status": "healthy"})
