"""
Tests unitaires Lambda B.
On ne touche jamais AWS — tout est mocké.
"""

import json
from unittest.mock import MagicMock, patch

import pytest

from handler import handler
from processor import process_message
from sns import publish_notification


# ── Helpers ───────────────────────────────────

def _make_sqs_record(message_id: str, detail: dict) -> dict:
    """Construit un record SQS contenant une enveloppe EventBridge."""
    eb_event = {
        "source": "myftpdr.lambda-a",
        "detail-type": "ProcessingComplete",
        "detail": detail,
    }
    return {
        "messageId": message_id,
        "body": json.dumps(eb_event),
    }


def _make_detail(action: str = "process", data: dict | None = None) -> dict:
    return {
        "id": "req-123",
        "payload": {"action": action, "data": data or {"key": "value"}},
        "received_at": "2026-01-01T00:00:00+00:00",
        "source_ip": "1.2.3.4",
    }


@pytest.fixture
def lambda_context():
    ctx = MagicMock()
    ctx.aws_request_id = "test-ctx-id"
    return ctx


# ── Tests handler ──────────────────────────────

class TestHandler:

    @patch("handler.publish_notification")
    def test_valid_batch_returns_no_failures(self, mock_publish, lambda_context, monkeypatch):
        monkeypatch.setenv("SNS_ARN", "arn:aws:sns:eu-west-3:123:test")
        mock_publish.return_value = "msg-id-1"
        event = {
            "Records": [
                _make_sqs_record("msg-1", _make_detail("process")),
                _make_sqs_record("msg-2", _make_detail("analyze", {"x": 1, "y": 2})),
            ]
        }
        result = handler(event, lambda_context)
        assert result == {"batchItemFailures": []}
        assert mock_publish.call_count == 2

    @patch("handler.publish_notification", side_effect=Exception("SNS down"))
    def test_sns_failure_adds_batch_item_failure(self, mock_publish, lambda_context):
        event = {"Records": [_make_sqs_record("msg-fail", _make_detail())]}
        result = handler(event, lambda_context)
        assert result == {"batchItemFailures": [{"itemIdentifier": "msg-fail"}]}

    @patch("handler.publish_notification")
    def test_partial_batch_failure(self, mock_publish, lambda_context, monkeypatch):
        monkeypatch.setenv("SNS_ARN", "arn:aws:sns:eu-west-3:123:test")
        mock_publish.side_effect = [None, Exception("boom")]
        event = {
            "Records": [
                _make_sqs_record("msg-ok", _make_detail()),
                _make_sqs_record("msg-ko", _make_detail()),
            ]
        }
        result = handler(event, lambda_context)
        assert result == {"batchItemFailures": [{"itemIdentifier": "msg-ko"}]}

    @patch("handler.publish_notification")
    def test_malformed_body_adds_failure(self, mock_publish, lambda_context):
        record = {"messageId": "bad-msg", "body": "not-json"}
        result = handler({"Records": [record]}, lambda_context)
        assert result == {"batchItemFailures": [{"itemIdentifier": "bad-msg"}]}

    def test_empty_batch_returns_no_failures(self, lambda_context):
        result = handler({"Records": []}, lambda_context)
        assert result == {"batchItemFailures": []}


# ── Tests processor ───────────────────────────

class TestProcessor:

    def test_process_action(self):
        detail = _make_detail("process", {"a": 1, "b": 2})
        result = process_message(detail)
        assert result["status"] == "processed"
        assert result["action"] == "process"
        assert result["output"]["count"] == 2

    def test_analyze_action(self):
        detail = _make_detail("analyze", {"x": 10, "y": 20})
        result = process_message(detail)
        assert result["output"]["sum"] == 30
        assert result["output"]["numeric_fields"] == 2

    def test_transform_action(self):
        detail = _make_detail("transform", {"hello": "world"})
        result = process_message(detail)
        assert "HELLO" in result["output"]["transformed"]

    def test_unknown_action_raises(self):
        detail = _make_detail("unknown_action")
        with pytest.raises(ValueError, match="Action inconnue"):
            process_message(detail)

    def test_missing_action_raises(self):
        detail = {"id": "x", "payload": {"data": {}}, "received_at": "", "source_ip": ""}
        with pytest.raises(ValueError, match="action"):
            process_message(detail)


# ── Tests sns ─────────────────────────────────

class TestSNS:

    def test_publish_returns_message_id(self):
        mock_client = MagicMock()
        mock_client.publish.return_value = {"MessageId": "sns-abc-123"}
        result = publish_notification(
            client=mock_client,
            topic_arn="arn:aws:sns:eu-west-3:123:test",
            subject="Test",
            message={"status": "processed", "action": "process", "result": {}},
        )
        assert result == "sns-abc-123"
        mock_client.publish.assert_called_once()
