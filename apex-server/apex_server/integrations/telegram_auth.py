"""Telegram authentication — link chat_id to Apex user via 6-digit code"""
import uuid
import random
import time
from typing import Optional, Dict, Tuple

from sqlalchemy.orm import Session

from apex_server.shared.database import SessionLocal
from apex_server.auth.models import User


# In-memory store for link codes: code -> (user_id, expires_at)
# In production, use Redis or database
_link_codes: Dict[str, Tuple[str, float]] = {}

CODE_EXPIRY_SECONDS = 300  # 5 minutes


def generate_link_code(user_id: uuid.UUID) -> str:
    """Generate a 6-digit code for linking Telegram to a user account.

    Returns the code. Valid for 5 minutes.
    """
    # Clean up expired codes
    now = time.time()
    expired = [c for c, (_, exp) in _link_codes.items() if exp < now]
    for c in expired:
        del _link_codes[c]

    # Remove any existing code for this user
    user_id_str = str(user_id)
    existing = [c for c, (uid, _) in _link_codes.items() if uid == user_id_str]
    for c in existing:
        del _link_codes[c]

    # Generate new 6-digit code
    code = f"{random.randint(100000, 999999)}"
    _link_codes[code] = (user_id_str, now + CODE_EXPIRY_SECONDS)

    return code


def verify_link_code(code: str, chat_id: str) -> Optional[User]:
    """Verify a 6-digit code and link the Telegram chat_id to the user.

    Returns the User on success, None if code is invalid or expired.
    """
    code = code.strip()

    if code not in _link_codes:
        return None

    user_id_str, expires_at = _link_codes[code]

    # Check expiry
    if time.time() > expires_at:
        del _link_codes[code]
        return None

    # Code is valid - link the user
    del _link_codes[code]

    db: Session = SessionLocal()
    try:
        user = db.query(User).filter(User.id == uuid.UUID(user_id_str)).first()
        if not user:
            return None

        user.telegram_chat_id = str(chat_id)
        db.commit()
        db.refresh(user)
        return user
    finally:
        db.close()


def link_telegram(token: str, chat_id: str) -> Optional[User]:
    """Verify a JWT token and link the Telegram chat_id to the user.

    (Legacy method - kept for backwards compatibility)
    Returns the User on success, None if the token is invalid.
    """
    from apex_server.auth.service import AuthService

    payload = AuthService.decode_token(token)
    if not payload:
        return None

    user_id = payload.get("sub")
    if not user_id:
        return None

    db: Session = SessionLocal()
    try:
        user = db.query(User).filter(User.id == uuid.UUID(user_id)).first()
        if not user:
            return None

        user.telegram_chat_id = str(chat_id)
        db.commit()
        db.refresh(user)
        return user
    finally:
        db.close()


def get_user_by_chat_id(chat_id: str) -> Optional[User]:
    """Look up an Apex user by their Telegram chat_id."""
    db: Session = SessionLocal()
    try:
        return db.query(User).filter(User.telegram_chat_id == str(chat_id)).first()
    finally:
        db.close()


def get_user_by_id(user_id: uuid.UUID) -> Optional[User]:
    """Look up an Apex user by their id (for notifications)."""
    db: Session = SessionLocal()
    try:
        return db.query(User).filter(User.id == user_id).first()
    finally:
        db.close()
