"""
Tests unitaires Lambda A.
On ne touche jamais AWS — tout est mocké.
"""

import json
from unittest.mock import MagicMock, patch

import pytest

from handler import handler
from validators import validate_payload
from eventbridge import publish_event


# ── Fixtures ──────────────────────────────────

@pytest.fixture
def apigw_event():
    """Événement API Gateway v2 minimal valide."""
    return {
        "rawPath": "/process",
        "requestContext": {
            "http": {"method": "POST", "sourceIp": "1.2.3.4"}
        },
        "body": json.dumps({
            "action": "process",
            "data": {"key": "value"}
        }),
        "isBase64Encoded": False,
    }


@pytest.fixture
def lambda_context():
    ctx = MagicMock()
    ctx.aws_request_id = "test-request-id-123"
    return ctx


# ── Tests handler ──────────────────────────────

class TestHandler:

    def test_healthcheck_returns_200(self, lambda_context):
        event = {"rawPath": "/health", "requestContext": {}}
        response = handler(event, lambda_context)
        assert response["statusCode"] == 200
        body = json.loads(response["body"])
        assert body["status"] == "ok"
        assert body["lambda"] == "A"

    @patch("handler.publish_event")
    @patch("handler.eventbridge_client")
    def test_valid_request_returns_202(
        self, mock_client, mock_publish, apigw_event, lambda_context, monkeypatch
    ):
        monkeypatch.setenv("EVENT_BUS_NAME", "test-bus")
        monkeypatch.setenv("EVENT_SOURCE", "myftpdr.lambda-a")
        monkeypatch.setenv("EVENT_DETAIL_TYPE", "ProcessingComplete")
        mock_publish.return_value = "evt-123"
        response = handler(apigw_event, lambda_context)
        assert response["statusCode"] == 202
        body = json.loads(response["body"])
        assert body["status"] == "accepted"
        assert "request_id" in body

    def test_invalid_json_returns_400(self, lambda_context):
        event = {
            "rawPath": "/process",
            "requestContext": {"http": {"method": "POST"}},
            "body": "not-json",
            "isBase64Encoded": False,
        }
        response = handler(event, lambda_context)
        assert response["statusCode"] == 400

    @patch("handler.publish_event")
    @patch("handler.eventbridge_client")
    def test_missing_field_returns_422(
        self, mock_client, mock_publish, lambda_context
    ):
        event = {
            "rawPath": "/process",
            "requestContext": {"http": {"method": "POST"}},
            "body": json.dumps({"action": "process"}),  # 'data' manquant
            "isBase64Encoded": False,
        }
        response = handler(event, lambda_context)
        assert response["statusCode"] == 422

    @patch("handler.publish_event", side_effect=Exception("AWS down"))
    @patch("handler.eventbridge_client")
    def test_eventbridge_failure_returns_502(
        self, mock_client, mock_publish, apigw_event, lambda_context, monkeypatch
    ):
        monkeypatch.setenv("EVENT_BUS_NAME", "test-bus")
        monkeypatch.setenv("EVENT_SOURCE", "myftpdr.lambda-a")
        monkeypatch.setenv("EVENT_DETAIL_TYPE", "ProcessingComplete")
        response = handler(apigw_event, lambda_context)
        assert response["statusCode"] == 502


# ── Tests validators ──────────────────────────

class TestValidators:

    def test_valid_payload_returns_no_errors(self):
        payload = {"action": "process", "data": {"key": "val"}}
        assert validate_payload(payload) == []

    def test_missing_action_returns_error(self):
        errors = validate_payload({"data": {}})
        assert any("action" in e for e in errors)

    def test_missing_data_returns_error(self):
        errors = validate_payload({"action": "process"})
        assert any("data" in e for e in errors)

    def test_unknown_action_returns_error(self):
        errors = validate_payload({"action": "hack", "data": {}})
        assert any("hack" in e for e in errors)

    def test_data_not_dict_returns_error(self):
        errors = validate_payload({"action": "process", "data": "string"})
        assert any("objet JSON" in e for e in errors)

    @pytest.mark.parametrize("action", ["process", "analyze", "transform"])
    def test_all_allowed_actions_pass(self, action):
        errors = validate_payload({"action": action, "data": {}})
        assert errors == []


# ── Tests eventbridge ─────────────────────────

class TestEventBridge:

    def test_publish_returns_event_id(self):
        mock_client = MagicMock()
        mock_client.put_events.return_value = {
            "FailedEntryCount": 0,
            "Entries": [{"EventId": "evt-abc-123"}],
        }
        result = publish_event(
            client=mock_client,
            bus_name="test-bus",
            source="myftpdr.lambda-a",
            detail_type="ProcessingComplete",
            detail={"id": "123", "payload": {}, "received_at": "", "source_ip": ""},
        )
        assert result == "evt-abc-123"

    def test_failed_entry_raises_exception(self):
        mock_client = MagicMock()
        mock_client.put_events.return_value = {
            "FailedEntryCount": 1,
            "Entries": [{"ErrorCode": "InternalFailure", "ErrorMessage": "Oops"}],
        }
        with pytest.raises(RuntimeError, match="EventBridge a rejeté"):
            publish_event(
                client=mock_client,
                bus_name="test-bus",
                source="src",
                detail_type="type",
                detail={},
            )
