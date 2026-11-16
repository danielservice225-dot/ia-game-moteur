from fastapi.testclient import TestClient
from backend.main import app

client = TestClient(app)


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_preview_csv():
    response = client.post(
        "/datasets/preview",
        files={"file": ("data.csv", b"x,y\n1,2\n1,2\n3,4\n", "text/csv")},
    )
    assert response.status_code == 200
    assert response.json()["rows_before"] == 3
    assert response.json()["rows_after"] == 2
