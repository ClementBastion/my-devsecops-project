"""
Abstraction de la publication EventBridge.
Isoler boto3 dans ce module facilite les tests unitaires
(on mock uniquement cette couche).
"""

import json
import logging
from typing import Any

logger = logging.getLogger(__name__)


def publish_event(
    client,
    bus_name: str,
    source: str,
    detail_type: str,
    detail: dict[str, Any],
) -> str:
    """
    Publie un événement sur EventBridge.

    Args:
        client     : boto3 EventBridge client
        bus_name   : nom du bus custom
        source     : source de l'événement (ex: "myftpdr.lambda-a")
        detail_type: type d'événement (ex: "ProcessingComplete")
        detail     : contenu de l'événement (sérialisé en JSON)

    Returns:
        ID de l'entrée publiée

    Raises:
        botocore.exceptions.ClientError si AWS retourne une erreur
    """
    response = client.put_events(
        Entries=[{
            "EventBusName": bus_name,
            "Source": source,
            "DetailType": detail_type,
            "Detail": json.dumps(detail, ensure_ascii=False),
        }]
    )

    failed = response.get("FailedEntryCount", 0)
    if failed > 0:
        error = response["Entries"][0]
        raise RuntimeError(
            f"EventBridge a rejeté l'événement : "
            f"{error.get('ErrorCode')} — {error.get('ErrorMessage')}"
        )

    entry_id = response["Entries"][0].get("EventId", "unknown")
    logger.debug("EventBridge entry ID : %s", entry_id)
    return entry_id
