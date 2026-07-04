import json

import httpx

from tests.test_chat import auth, client


REQUEST = {
    "date": "2026-07-04",
    "calendar": [{"title": "Design sync", "start": "10:00", "context": "business"}],
    "reminders": [{"title": "Call plumber", "context": "personal"}],
}


def test_briefing_routes_require_authentication() -> None:
    test_client = client()

    assert test_client.post("/briefing", json=REQUEST).status_code == 401
    assert test_client.get("/briefing/latest").status_code == 401


def test_briefing_returns_sections_and_persists_latest() -> None:
    def ollama_response(request: httpx.Request) -> httpx.Response:
        payload = json.loads(request.content)
        supplied = json.loads(payload["messages"][1]["content"])
        assert supplied == REQUEST
        return httpx.Response(
            200,
            json={
                "message": {
                    "content": json.dumps(
                        {
                            "personal": "Call the plumber.",
                            "business": "Design sync is at 10:00.",
                            "shared": "Nothing scheduled.",
                        }
                    )
                }
            },
        )

    test_client = client(httpx.MockTransport(ollama_response))
    response = test_client.post("/briefing", json=REQUEST, headers=auth())

    assert response.status_code == 200
    result = response.json()
    assert result["date"] == REQUEST["date"]
    assert result["business"] == "Design sync is at 10:00."
    assert result["route"] == "Tank"
    assert result["privacy_receipt"]["used"] == ["1 calendar items", "1 reminder items"]
    assert test_client.get("/briefing/latest", headers=auth()).json() == result


def test_briefing_timeout_maps_to_service_unavailable() -> None:
    def timeout(_: httpx.Request) -> httpx.Response:
        raise httpx.ReadTimeout("timed out")

    response = client(httpx.MockTransport(timeout)).post(
        "/briefing", json=REQUEST, headers=auth()
    )

    assert response.status_code == 503


def test_briefing_rejects_malformed_model_output() -> None:
    transport = httpx.MockTransport(
        lambda _: httpx.Response(200, json={"message": {"content": "not-json"}})
    )

    response = client(transport).post("/briefing", json=REQUEST, headers=auth())

    assert response.status_code == 502


def test_briefing_rejects_unknown_context() -> None:
    invalid = {**REQUEST, "calendar": [{"title": "Mystery", "start": "10:00", "context": "x"}]}

    response = client().post("/briefing", json=invalid, headers=auth())

    assert response.status_code == 422
