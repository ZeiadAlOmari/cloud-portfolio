from flask import Flask, jsonify
import psycopg2
import os

app = Flask(__name__)

DB_HOST = os.environ.get("DB_HOST", "localhost")
DB_NAME = os.environ.get("DB_NAME", "appdb")
DB_USER = os.environ.get("DB_USER", "admin")
DB_PASS = os.environ.get("DB_PASS", "password")

@app.route("/")
def home():
    return jsonify({
        "status": "running",
        "message": "Multi-Tier Application",
        "architecture": {
            "web_tier": "Nginx reverse proxy",
            "app_tier": "Flask on EC2",
            "db_tier": "PostgreSQL on RDS"
        }
    })

@app.route("/health")
def health():
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASS,
            connect_timeout=5
        )
        conn.close()
        return jsonify({"status": "healthy", "database": "connected"})
    except Exception as e:
        return jsonify({"status": "unhealthy", "database": str(e)}), 503

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)