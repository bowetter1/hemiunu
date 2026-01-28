"""Firebase Admin SDK wrapper for token verification"""
import json
from typing import Optional

_initialized = False


def _ensure_initialized():
    """Lazy-init Firebase Admin SDK from FIREBASE_CREDENTIALS_JSON env var"""
    global _initialized
    if _initialized:
        return True

    from apex_server.config import get_settings
    settings = get_settings()

    creds_json = settings.firebase_credentials_json
    if not creds_json:
        print("Firebase credentials missing (FIREBASE_CREDENTIALS_JSON empty)", flush=True)
        return False

    try:
        import firebase_admin
        from firebase_admin import credentials

        creds_dict = json.loads(creds_json)
        project_id = creds_dict.get("project_id", "unknown")
        print(f"Firebase credentials project_id={project_id}", flush=True)
        cred = credentials.Certificate(creds_dict)
        firebase_admin.initialize_app(cred)
        _initialized = True
        print("Firebase Admin SDK initialized", flush=True)
        return True
    except Exception as e:
        print(f"Firebase init failed: {e}", flush=True)
        return False


def verify_firebase_token(id_token: str) -> Optional[dict]:
    """Verify a Firebase ID token and return claims (uid, email, name) or None.

    Returns None if Firebase is not configured (local dev) or token is invalid.
    """
    if not _ensure_initialized():
        return None

    try:
        from firebase_admin import auth
        decoded = auth.verify_id_token(id_token)
        return {
            "uid": decoded["uid"],
            "email": decoded.get("email", ""),
            "name": decoded.get("name", ""),
        }
    except Exception as e:
        print(f"Firebase token verification failed: {e}", flush=True)
        return None
