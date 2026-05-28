"""
Validation du payload entrant.
Retourne une liste d'erreurs (vide = valide).
"""

REQUIRED_FIELDS = ["action", "data"]
ALLOWED_ACTIONS = ["process", "analyze", "transform"]
MAX_DATA_SIZE = 256 * 1024  # 256 Ko


def validate_payload(body: dict) -> list[str]:
    """
    Valide le payload métier.

    Returns:
        Liste de messages d'erreur. Vide si tout est OK.
    """
    errors = []

    # Champs obligatoires
    for field in REQUIRED_FIELDS:
        if field not in body:
            errors.append(f"Champ obligatoire manquant : '{field}'")

    if errors:
        return errors  # Pas la peine d'aller plus loin

    # Validation de l'action
    action = body.get("action", "")
    if not isinstance(action, str) or not action.strip():
        errors.append("Le champ 'action' doit être une chaîne non vide")
    elif action not in ALLOWED_ACTIONS:
        errors.append(
            f"Action '{action}' non reconnue. "
            f"Valeurs autorisées : {', '.join(ALLOWED_ACTIONS)}"
        )

    # Validation de data
    data = body.get("data")
    if not isinstance(data, dict):
        errors.append("Le champ 'data' doit être un objet JSON")
    elif len(str(data).encode("utf-8")) > MAX_DATA_SIZE:
        errors.append(f"Le champ 'data' dépasse la taille maximale ({MAX_DATA_SIZE // 1024} Ko)")

    return errors
