from dataclasses import dataclass
from typing import Any


@dataclass
class ProcessRequest:
    id: str
    payload: dict[str, Any]
    received_at: str
    source_ip: str

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "payload": self.payload,
            "received_at": self.received_at,
            "source_ip": self.source_ip,
        }
