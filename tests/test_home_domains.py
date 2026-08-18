"""A change-risk tool must not be able to reach secure hardware.

`control_home_device` is CHANGE risk and `control_secure_home_device` is
SENSITIVE, but the split was enforced by denying three domain names. Anything
not on that list -- including `script` and `automation`, which can do whatever
their author wrote, up to unlocking a door -- executed at the lower tier. That
broke the rule that an approval covers the risk it was granted for.
"""

import asyncio
import json
from pathlib import Path
from unittest.mock import MagicMock

import httpx
import pytest

from app.agent import AgentTaskRequest, TankAgent
from app.agent_store import AgentStore
from app.agent_tools import (
    ToolRegistry,
    ToolRisk,
    home_domain_of,
    home_domains_for,
)
from app.config import Settings


def _tools(tmp_path: Path) -> tuple[ToolRegistry, MagicMock]:
    home = MagicMock()
    home.is_configured = True
    home.call_service.return_value = {"status": "success", "response": {}}
    return ToolRegistry(tmp_path, tmp_path, home), home


# ------------------------------------------------------------------ #
# Classification                                                       #
# ------------------------------------------------------------------ #


@pytest.mark.parametrize("entity_id,domain", [("light.kitchen", "light"), ("a.b.c", "a")])
def test_domain_is_read_from_the_entity_id(entity_id: str, domain: str) -> None:
    assert home_domain_of(entity_id) == domain


@pytest.mark.parametrize("malformed", ["light", "", ".kitchen", "light.", "."])
def test_malformed_entity_ids_have_no_domain(malformed: str) -> None:
    """A missing dot previously yielded domain "" which passed the denylist."""
    assert home_domain_of(malformed) == ""


@pytest.mark.parametrize("domain", ["light", "switch", "climate", "media_player", "fan"])
def test_ordinary_domains_are_change_risk(domain: str) -> None:
    assert domain in home_domains_for(ToolRisk.CHANGE)


@pytest.mark.parametrize("domain", ["lock", "alarm_control_panel", "cover"])
def test_secure_domains_are_sensitive_risk(domain: str) -> None:
    assert domain in home_domains_for(ToolRisk.SENSITIVE)


@pytest.mark.parametrize(
    "domain",
    [
        # Indirection: runs whatever its author wrote, so no tier covers it.
        "script",
        "automation",
        "scene",
        "button",
        "homeassistant",
        # Simply not classified yet. The allowlist refuses these rather than
        # letting a new or unknown domain default into the lower tier.
        "vacuum",
        "water_heater",
        "lawn_mower",
        "made_up",
    ],
)
def test_unclassified_domains_are_in_neither_tier(domain: str) -> None:
    assert domain not in home_domains_for(ToolRisk.CHANGE)
    assert domain not in home_domains_for(ToolRisk.SENSITIVE)


# ------------------------------------------------------------------ #
# The escape this closes                                               #
# ------------------------------------------------------------------ #


@pytest.mark.parametrize(
    "entity_id",
    [
        "script.unlock_front_door",
        "automation.disarm_alarm",
        "button.open_garage",
        "homeassistant.turn_off",
    ],
)
def test_change_tool_cannot_reach_indirection_domains(tmp_path: Path, entity_id: str) -> None:
    tools, home = _tools(tmp_path)

    with pytest.raises(ValueError, match="does not control"):
        tools.execute("control_home_device", {"entity_id": entity_id, "service": "turn_on"})

    home.call_service.assert_not_called()


def test_secure_tool_also_cannot_reach_indirection_domains(tmp_path: Path) -> None:
    """Escalating the tier must not be a way in either."""
    tools, home = _tools(tmp_path)

    with pytest.raises(ValueError, match="does not control"):
        tools.execute(
            "control_secure_home_device",
            {"entity_id": "script.unlock_front_door", "service": "turn_on"},
        )

    home.call_service.assert_not_called()


def test_scene_refusal_points_at_the_scene_tool(tmp_path: Path) -> None:
    tools, _ = _tools(tmp_path)

    with pytest.raises(ValueError, match="run_home_scene"):
        tools.execute(
            "control_home_device", {"entity_id": "scene.good_night", "service": "turn_on"}
        )


def test_unknown_domain_is_refused_rather_than_executed(tmp_path: Path) -> None:
    tools, home = _tools(tmp_path)

    with pytest.raises(ValueError, match="does not control"):
        tools.execute("control_home_device", {"entity_id": "vacuum.roomba", "service": "start"})

    home.call_service.assert_not_called()


def test_malformed_entity_id_is_refused(tmp_path: Path) -> None:
    tools, home = _tools(tmp_path)

    with pytest.raises(ValueError, match=r"domain\.object_id"):
        tools.execute("control_home_device", {"entity_id": "justaname", "service": "turn_on"})

    home.call_service.assert_not_called()


# ------------------------------------------------------------------ #
# Retargeting                                                          #
# ------------------------------------------------------------------ #


@pytest.mark.parametrize("key", ["area_id", "device_id", "entity_id", "floor_id", "label_id"])
def test_service_data_cannot_retarget_the_call(tmp_path: Path, key: str) -> None:
    """Home Assistant accepts area/device targeting inside the payload.

    Left through, one approved entity_id could stand in for a whole area and the
    stored approval would no longer describe what actually ran.
    """
    tools, home = _tools(tmp_path)

    with pytest.raises(ValueError, match="only thing this call may affect"):
        tools.execute(
            "control_home_device",
            {
                "entity_id": "light.kitchen",
                "service": "turn_on",
                "service_data": {key: "everything"},
            },
        )

    home.call_service.assert_not_called()


def test_ordinary_service_data_still_passes_through(tmp_path: Path) -> None:
    tools, home = _tools(tmp_path)

    result = tools.execute(
        "control_home_device",
        {
            "entity_id": "light.kitchen",
            "service": "turn_on",
            "service_data": {"brightness_pct": 40},
        },
    )

    assert result["status"] == "success"
    home.call_service.assert_called_once_with(
        "light", "turn_on", {"brightness_pct": 40, "entity_id": "light.kitchen"}
    )


@pytest.mark.parametrize("service", ["turn on", "../../unlock", "TURN_ON", "", "a" * 51])
def test_service_names_are_validated(tmp_path: Path, service: str) -> None:
    tools, home = _tools(tmp_path)

    with pytest.raises(ValueError):
        tools.execute("control_home_device", {"entity_id": "light.kitchen", "service": service})

    home.call_service.assert_not_called()


# ------------------------------------------------------------------ #
# Risk tiers are unchanged                                             #
# ------------------------------------------------------------------ #


def test_risk_tiers(tmp_path: Path) -> None:
    tools, _ = _tools(tmp_path)

    assert tools.get("control_home_device").risk is ToolRisk.CHANGE
    assert tools.get("control_secure_home_device").risk is ToolRisk.SENSITIVE


def test_secure_domains_still_route_to_the_sensitive_tool(tmp_path: Path) -> None:
    tools, home = _tools(tmp_path)

    with pytest.raises(ValueError, match="must go through control_secure_home_device"):
        tools.execute("control_home_device", {"entity_id": "lock.front", "service": "unlock"})

    result = tools.execute(
        "control_secure_home_device", {"entity_id": "lock.front", "service": "unlock"}
    )
    assert result["status"] == "success"
    home.call_service.assert_called_once_with("lock", "unlock", {"entity_id": "lock.front"})


# ------------------------------------------------------------------ #
# Refusals must not become approvals                                   #
# ------------------------------------------------------------------ #


def _agent_run(tmp_path: Path, entity_id: str) -> tuple[AgentStore, object]:
    """Drive one agent turn where the model asks for `entity_id`."""
    store = AgentStore(":memory:")
    tools, _ = _tools(tmp_path)
    tool_call = {
        "message": {
            "role": "assistant",
            "content": "",
            "tool_calls": [
                {
                    "type": "function",
                    "function": {
                        "name": "control_home_device",
                        "arguments": {"entity_id": entity_id, "service": "turn_on"},
                    },
                }
            ],
        }
    }
    agent = TankAgent(
        settings=Settings(agent_database_path=":memory:", agent_max_steps=1),
        store=store,
        tools=tools,
        transport=httpx.MockTransport(lambda _: httpx.Response(200, json=tool_call)),
    )
    response = asyncio.run(agent.run(AgentTaskRequest(objective="turn it on")))
    return store, response


def test_refused_domain_creates_no_approval(tmp_path: Path) -> None:
    """The user must never be asked to authorize a call that cannot run.

    Approvals are created from the model's raw arguments before any handler
    runs, so without a validation seam a `script.*` request became a pending
    approval that could only ever fail once approved.
    """
    store, response = _agent_run(tmp_path, "script.unlock_front_door")

    assert store.list_approvals("pending") == []
    assert response.approvals == []


def test_refusal_is_reported_to_the_model_and_audited(tmp_path: Path) -> None:
    store, _ = _agent_run(tmp_path, "script.unlock_front_door")

    events = [
        json.loads(row["detail_json"])
        for row in store._connect().execute(
            "SELECT detail_json FROM audit_events WHERE event_type = 'tool_refused'"
        )
    ]
    assert len(events) == 1
    assert "does not control" in events[0]["error"]


def test_permitted_domain_still_creates_an_approval(tmp_path: Path) -> None:
    store, response = _agent_run(tmp_path, "light.kitchen")

    pending = store.list_approvals("pending")
    assert len(pending) == 1
    assert pending[0]["tool_name"] == "control_home_device"
    assert pending[0]["risk"] == ToolRisk.CHANGE
    assert len(response.approvals) == 1
