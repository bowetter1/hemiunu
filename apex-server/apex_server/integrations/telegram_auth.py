"""Telegram authentication — link chat_id to Apex user via JWT token"""
import uuid
from typing import Optional

from sqlalchemy.orm import Session

from apex_server.shared.database import SessionLocal
from apex_server.auth.service import AuthService
from apex_server.auth.models import User


def link_telegram(token: str, chat_id: str) -> Optional[User]:
    """Verify a JWT token and link the Telegram chat_id to the user.

    Returns the User on success, None if the token is invalid.
    """
    auth_service_cls = AuthService  # only need static method
    payload = auth_service_cls.decode_token(token)
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
