import json

import httpx

from tests.test_chat import auth, client

REQUEST = {
    "date": "2026-07-04",
    "calendar": [
        {"title": "Design sync", "start": "10:00", "end": "11:00", "context": "business"}
    ],
    "reminders": [{"title": "Call plumber", "due": "14:00", "context": "personal"}],
}


def test_briefing_routes_require_authentication() -> None:
    test_client = client()

    assert test_client.post("/briefing", json=REQUEST).status_code == 401
    assert test_client.get("/briefing/latest").status_code == 401


def test_briefing_constrains_decoding_to_the_schema_it_validates() -> None:
    """The request must carry the briefing schema, not free-form JSON mode.

    Asking for `"format": "json"` and validating afterwards turns a model that
    drifts off-shape into a failed briefing for the user. Sending the schema
    Ollama should constrain against removes that failure mode, so the schema
    travelling with the request is the behaviour worth pinning.
    """
    seen: dict = {}

    def ollama_response(request: httpx.Request) -> httpx.Response:
        seen.update(json.loads(request.content))
        return httpx.Response(200, json={"message": {"content": "not json"}})

    transport = httpx.MockTransport(ollama_response)
    client(transport=transport).post("/briefing", json=REQUEST, headers=auth())

    schema = seen.get("format")
    assert isinstance(schema, dict), "briefing must send a JSON Schema, not 'json'"
    assert schema.get("type") == "object"
    assert "topline" in schema.get("properties", {})


def test_briefing_returns_sections_and_persists_latest() -> None:
    def ollama_response(request: httpx.Request) -> httpx.Response:
        payload = json.loads(request.content)
        supplied = json.loads(payload["messages"][1]["content"])
        assert supplied["date"] == REQUEST["date"]
        assert supplied["reminders"] == REQUEST["reminders"]
        assert supplied["calendar"][0]["title"] == "Design sync"
        assert supplied["calendar"][0]["start"] == "10:00"
        assert supplied["calendar"][0]["end"] == "11:00"
        assert supplied["calendar"][0]["context"] == "business"
        return httpx.Response(
            200,
            json={
                "message": {
                    "content": json.dumps(
                        {
                            "topline": "This is a focused day with one key meeting.",
                            "priorities": [
                                "Business · Design sync (10:00)",
                                "Personal · Call plumber",
                                "Personal · Reserve prep block",
                            ],
                            "conflicts_or_risks": [],
                            "recommended_plan": [
                                "Prep for Design sync before 09:30.",
                                "Handle quick admin after the meeting.",
                            ],
                            "one_useful_question": None,
                            "suggested_next_actions": [
                                "Review your notes for Design sync.",
                                "Set a reminder to call plumber after lunch.",
                            ],
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
    assert result["topline"] == "This is a focused day with one key meeting."
    assert len(result["priorities"]) >= 3
    assert "No major schedule risks detected right now." in result["conflicts_or_risks"]
    assert result["route"] == "Tank"
    assert result["privacy_receipt"]["used"] == ["1 calendar items", "1 reminder items"]
    assert test_client.get("/briefing/latest", headers=auth()).json() == result


def test_briefing_adds_heuristic_conflict_signals() -> None:
    request = {
        "date": "2026-07-04",
        "calendar": [
            {"title": "Board review", "start": "08:00", "end": "09:00", "context": "business"},
            {"title": "Interview panel", "start": "09:05", "end": "10:00", "context": "business"},
            {"title": "Launch prep", "start": "10:05", "end": "11:00", "context": "business"},
            {"title": "Team sync", "start": "11:05", "end": "11:45", "context": "business"},
        ],
        "reminders": [],
    }

    def ollama_response(_: httpx.Request) -> httpx.Response:
        return httpx.Response(
            200,
            json={
                "message": {
                    "content": json.dumps(
                        {
                            "topline": "Busy morning.",
                            "priorities": ["Business · Board review (08:00)"],
                            "conflicts_or_risks": [],
                            "recommended_plan": ["Hold prep before 08:00."],
                            "one_useful_question": None,
                            "suggested_next_actions": ["Review agenda now."],
                        }
                    )
                }
            },
        )

    response = client(httpx.MockTransport(ollama_response)).post(
        "/briefing",
        json=request,
        headers=auth(),
    )

    assert response.status_code == 200
    result = response.json()
    assert any("transition" in risk.lower() for risk in result["conflicts_or_risks"])


def test_briefing_timeout_maps_to_service_unavailable() -> None:
    def timeout(_: httpx.Request) -> httpx.Response:
        raise httpx.ReadTimeout("timed out")

    response = client(httpx.MockTransport(timeout)).post("/briefing", json=REQUEST, headers=auth())

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
