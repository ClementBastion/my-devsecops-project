"""
Abstraction de la publication SNS.
Isolée pour faciliter les tests unitaires.
"""

import json
import logging
from typing import Any

logger = logging.getLogger(__name__)


def publish_notification(
    client,
    topic_arn: str,
    subject: str,
    message: dict[str, Any],
) -> str:
    """
    Publie une notification sur SNS.

    Args:
        client    : boto3 SNS client
        topic_arn : ARN du topic cible
        subject   : sujet du message (email)
        message   : contenu sérialisé en JSON

    Returns:
        MessageId SNS

    Raises:
        botocore.exceptions.ClientError si AWS échoue
    """
    response = client.publish(
        TopicArn=topic_arn,
        Subject=subject[:100],  # SNS limite le sujet à 100 caractères
        Message=json.dumps(message, ensure_ascii=False, indent=2),
        MessageAttributes={
            "status": {
                "DataType": "String",
                "StringValue": message.get("status", "unknown"),
            },
            "action": {
                "DataType": "String",
                "StringValue": message.get("result", {}).get("action", "unknown"),
            },
        },
    )

    message_id = response["MessageId"]
    logger.debug("SNS message publié : %s", message_id)
    return message_id
