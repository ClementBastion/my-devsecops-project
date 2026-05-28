# ══════════════════════════════════════════════
# Lambda B — Consommateur SQS
#
# Reçoit un batch de messages SQS (jusqu'à 10)
# Chaque message est un événement EventBridge enveloppé par SQS
# Traite le détail via processor.py
# Publie le résultat sur SNS
# Retourne les batchItemFailures pour le retry partiel
# ══════════════════════════════════════════════

import json
import logging
import os

import boto3

from processor import process_message
from sns import publish_notification

logger = logging.getLogger(__name__)
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

sns_client = boto3.client(
    "sns",
    region_name=os.environ.get("AWS_REGION", "eu-west-3")
)


def handler(event: dict, context) -> dict:
    records = event.get("Records", [])
    batch_item_failures = []

    logger.info("Batch reçu", extra={"record_count": len(records)})

    for record in records:
        message_id = record["messageId"]
        try:
            # Le body SQS contient l'enveloppe EventBridge sérialisée en JSON
            eb_event = json.loads(record["body"])
            detail = eb_event.get("detail", {})

            result = process_message(detail)

            publish_notification(
                client=sns_client,
                topic_arn=os.environ["SNS_ARN"],
                subject=f"[{os.environ.get('ENVIRONMENT', 'dev')}] Traitement {result['action']}",
                message=result,
            )

            logger.info("Message traité avec succès", extra={
                "message_id": message_id,
                "request_id": result.get("request_id"),
                "action": result.get("action"),
            })

        except Exception as e:
            logger.error("Échec traitement message", extra={
                "message_id": message_id,
                "error": str(e),
            })
            # Signale ce message comme en échec — SQS le retente (max 3 fois puis DLQ)
            batch_item_failures.append({"itemIdentifier": message_id})

    return {"batchItemFailures": batch_item_failures}
