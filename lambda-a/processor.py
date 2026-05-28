"""
Logique métier Lambda B.
Traite le détail de l'événement reçu depuis EventBridge via SQS.
"""

import logging
from datetime import datetime, timezone

logger = logging.getLogger(__name__)

def process_message(detail: dict) -> dict:
    """
    Dispatch vers le bon handler selon l'action.

    Args:
        detail : contenu du ProcessRequest (id, payload, received_at, source_ip)

    Returns:
        Résultat du traitement avec statut et métadonnées

    Raises:
        ValueError si l'action est inconnue
        KeyError si le detail est malformé
    """
    payload = detail.get("payload", {})
    action = payload.get("action")

    if not action:
        raise ValueError("Champ 'action' manquant dans le payload")

    ACTION_HANDLERS = {
        "process":   _handle_process,
        "analyze":   _handle_analyze,
        "transform": _handle_transform,
    }

    handler_fn = ACTION_HANDLERS.get(action)
    if not handler_fn:
        raise ValueError(f"Action inconnue : '{action}'")

    logger.info("Dispatch action", extra={"action": action, "request_id": detail.get("id")})

    result = handler_fn(payload.get("data", {}))

    return {
        "status": "processed",
        "action": action,
        "request_id": detail.get("id"),
        "processed_at": datetime.now(timezone.utc).isoformat(),
        "output": result,
    }


def _handle_process(data: dict) -> dict:
    """Traitement standard — transformation des données."""
    return {
        "type": "process",
        "keys_processed": list(data.keys()),
        "count": len(data),
    }


def _handle_analyze(data: dict) -> dict:
    """Analyse des données — statistiques basiques."""
    numeric_values = [v for v in data.values() if isinstance(v, (int, float))]
    return {
        "type": "analyze",
        "total_fields": len(data),
        "numeric_fields": len(numeric_values),
        "sum": sum(numeric_values) if numeric_values else 0,
    }


def _handle_transform(data: dict) -> dict:
    """Transformation — normalisation des clés en majuscules."""
    return {
        "type": "transform",
        "transformed": {k.upper(): v for k, v in data.items()},
    }
