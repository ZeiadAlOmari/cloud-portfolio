from app import app


def test_home():
    response = app.test_client().get("/")
    assert response.status_code == 200
    data = response.get_json()
    assert data["status"] == "running"
    assert data["version"] == "2.0.0"


def test_home_reports_digest(monkeypatch):
    monkeypatch.setenv("IMAGE_DIGEST", "sha256:" + "a" * 64)
    assert app.test_client().get("/").get_json()["image_digest"] == "sha256:" + "a" * 64


def test_health():
    response = app.test_client().get("/health")
    assert response.status_code == 200
    assert response.get_json() == {"status": "healthy"}


def test_unknown_route_is_404():
    assert app.test_client().get("/admin").status_code == 404
