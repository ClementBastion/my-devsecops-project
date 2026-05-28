# ══════════════════════════════════════════════
# Lambda A — Point d'entrée API Gateway
#
# Reçoit une requête HTTP POST /process
# Valide le payload
# Publie un événement sur EventBridge
# Retourne une réponse HTTP
# ══════════════════════════════════════════════

import json
import logging
import os
import uuid
from datetime import datetime, timezone

import boto3
from botocore.exceptions import ClientError

from models import ProcessRequest
from validators import validate_payload
from eventbridge import publish_event

# Logger structuré
logger = logging.getLogger(__name__)
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

# Client EventBridge initialisé en dehors du handler
# (réutilisé entre les invocations — warm start)
eventbridge_client = boto3.client(
    "events",
    region_name=os.environ.get("AWS_REGION", "eu-west-3")
)


def handler(event: dict, context) -> dict:
    """
    Handler principal Lambda A.

    Args:
        event : payload API Gateway v2 (HTTP API)
        context : contexte Lambda (request_id, remaining_time...)

    Returns:
        Réponse HTTP au format API Gateway v2
    """
    request_id = context.aws_request_id
    logger.info("Invocation démarrée", extra={
        "request_id": request_id,
        "path": event.get("rawPath"),
        "method": event.get("requestContext", {}).get("http", {}).get("method"),
    })

    # ── Healthcheck ──
    path = event.get("rawPath", "")
    if path == "/health":
        return _response(200, {"status": "ok", "lambda": "A", "request_id": request_id})

    # ── Lecture du body ──
    try:
        body = _parse_body(event)
    except ValueError as e:
        logger.warning("Payload invalide", extra={"error": str(e), "request_id": request_id})
        return _response(400, {"error": "Payload JSON invalide", "detail": str(e)})

    # ── Validation métier ──
    errors = validate_payload(body)
    if errors:
        logger.warning("Validation échouée", extra={"errors": errors, "request_id": request_id})
        return _response(422, {"error": "Données invalides", "details": errors})

    # ── Construction de l'objet métier ──
    request = ProcessRequest(
        id=str(uuid.uuid4()),
        payload=body,
        received_at=datetime.now(timezone.utc).isoformat(),
        source_ip=event.get("requestContext", {})
                       .get("http", {})
                       .get("sourceIp", "unknown"),
    )

    # ── Publication sur EventBridge ──
    try:
        event_id = publish_event(
            client=eventbridge_client,
            bus_name=os.environ["EVENT_BUS_NAME"],
            source=os.environ["EVENT_SOURCE"],
            detail_type=os.environ["EVENT_DETAIL_TYPE"],
            detail=request.to_dict(),
        )
        logger.info("Événement publié", extra={
            "event_id": event_id,
            "request_id": request.id,
        })
    except Exception as e:
        logger.error("Échec publication EventBridge", extra={
            "error": str(e),
            "request_id": request_id,
        })
        return _response(502, {"error": "Erreur interne — réessayez plus tard"})

    return _response(202, {
        "status": "accepted",
        "request_id": request.id,
        "message": "Traitement en cours",
    })


def _parse_body(event: dict) -> dict:
    """Parse le body HTTP — gère base64 et JSON."""
    body = event.get("body", "{}")

    if event.get("isBase64Encoded"):
        import base64
        body = base64.b64decode(body).decode("utf-8")

    if isinstance(body, str):
        return json.loads(body)

    return body or {}


def _response(status_code: int, body: dict) -> dict:
    """Formate une réponse API Gateway v2."""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "X-Request-Id": body.get("request_id", ""),
        },
        "body": json.dumps(body, ensure_ascii=False),
    }
