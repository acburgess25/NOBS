import json
import os
import subprocess
import sys
from pathlib import Path

import httpx
import pytest

from app.contract.v1 import (
    BriefingCalendarItem,
    BriefingRequest,
    BriefingResponse,
    PrivacyReceipt,
    SyncCalendarRequest,
    SyncRemindersRequest,
)
from tests.test_chat import auth, client

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "contracts" / "v1"
FIXTURES = CONTRACT / "fixtures"


def fixture(name: str) -> dict:
    return json.loads((FIXTURES / f"{name}.json").read_text(encoding="utf-8"))


def assert_no_location_key(value) -> None:
    if isinstance(value, dict):
        assert "location" not in value
        for child in value.values():
            assert_no_location_key(child)
    elif isinstance(value, list):
        for child in value:
            assert_no_location_key(child)


@pytest.mark.parametrize(
    ("name", "model"),
    [
        ("briefing_request", BriefingRequest),
        ("briefing_response", BriefingResponse),
        ("sync_calendar_request", SyncCalendarRequest),
        ("sync_reminders_request", SyncRemindersRequest),
        ("privacy_receipt", PrivacyReceipt),
    ],
)
def test_fixtures_match_models(name, model) -> None:
    value = fixture(name)
    assert model.model_validate(value).model_dump(mode="json", exclude_unset=True) == value


def test_openapi_matches_running_app_and_is_reproducible(tmp_path) -> None:
    expected = (CONTRACT / "openapi.json").read_text(encoding="utf-8")
    assert expected == json.dumps(client().app.openapi(), indent=2, sort_keys=True) + "\n"

    output = tmp_path / "openapi.json"
    env = {**os.environ, "NOBS_VERSION": "not-the-contract-version"}
    subprocess.run(
        [sys.executable, "-m", "scripts.export_openapi", "--output", str(output)],
        cwd=ROOT,
        env=env,
        check=True,
    )
    assert output.read_text(encoding="utf-8") == expected


def test_calendar_contract_and_fixtures_exclude_location() -> None:
    schema = json.loads((CONTRACT / "openapi.json").read_text(encoding="utf-8"))
    assert "location" not in BriefingCalendarItem.model_json_schema()["properties"]
    assert "location" not in schema["components"]["schemas"]["BriefingCalendarItem"]["properties"]
    for path in FIXTURES.glob("*.json"):
        assert_no_location_key(json.loads(path.read_text(encoding="utf-8")))
    for receipt in [fixture("privacy_receipt"), fixture("briefing_response")["privacy_receipt"]]:
        assert "location" not in json.dumps(receipt).lower()

    legacy = {**fixture("briefing_request")["calendar"][0], "location": "Private place"}
    assert "location" not in BriefingCalendarItem.model_validate(legacy).model_dump()


def test_fixtures_match_actual_endpoints() -> None:
    expected = fixture("briefing_response")
    section_keys = (
        "topline",
        "priorities",
        "conflicts_or_risks",
        "recommended_plan",
        "one_useful_question",
        "suggested_next_actions",
    )
    model_response = {key: expected[key] for key in section_keys}
    transport = httpx.MockTransport(
        lambda _: httpx.Response(200, json={"message": {"content": json.dumps(model_response)}})
    )
    test_client = client(transport)
    response = test_client.post("/briefing", json=fixture("briefing_request"), headers=auth())
    assert response.status_code == 200
    actual = response.json()
    assert actual.pop("generated_at")
    expected.pop("generated_at")
    assert actual == expected
    assert test_client.get("/briefing/latest", headers=auth()).json() == response.json()
    for path, name in [
        ("/sync/calendar", "sync_calendar_request"),
        ("/sync/reminders", "sync_reminders_request"),
    ]:
        result = test_client.post(path, json=fixture(name), headers=auth())
        assert result.status_code == 200
        assert result.json() == {"status": "ok"}
