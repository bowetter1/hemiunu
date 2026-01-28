"""Shared dependencies for FastAPI"""
import uuid
import re

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from .database import get_db

security = HTTPBearer()


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
):
    """Get current user from Firebase token (preferred) or HS256 JWT (dev fallback)"""
    from apex_server.auth.firebase import verify_firebase_token
    from apex_server.auth.service import AuthService
    from apex_server.auth.models import User
    from apex_server.tenants.service import TenantService

    token = credentials.credentials

    # Path 1: Firebase
    firebase_claims = verify_firebase_token(token)
    if firebase_claims:
        uid = firebase_claims["uid"]
        email = firebase_claims.get("email", "")
        name = firebase_claims.get("name", "") or email.split("@")[0]

        user = db.query(User).filter(User.firebase_uid == uid).first()

        if not user:
            # Check if email already exists (link accounts)
            user = db.query(User).filter(User.email == email).first()
            if user:
                user.firebase_uid = uid
                db.commit()
            else:
                # New user → pending approval
                tenant_service = TenantService(db)
                slug = re.sub(r'[^a-z0-9-]', '-', email.split("@")[0].lower())
                # Ensure unique slug
                base_slug = slug
                counter = 1
                while tenant_service.get_by_slug(slug):
                    slug = f"{base_slug}-{counter}"
                    counter += 1

                tenant = tenant_service.create(name=name, slug=slug)
                user = User(
                    email=email,
                    password_hash="firebase",
                    name=name,
                    tenant_id=tenant.id,
                    role="member",
                    firebase_uid=uid,
                    status="pending",
                )
                db.add(user)
                db.commit()
                db.refresh(user)

        if user.status == "pending":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Awaiting admin approval",
            )
        if user.status == "rejected":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied",
            )
        return user

    # Path 2: HS256 fallback (dev token)
    auth_service = AuthService(db)
    payload = auth_service.decode_token(token)
    if payload:
        user = auth_service.get_by_id(uuid.UUID(payload["sub"]))
        if user:
            return user

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired token",
    )


def get_current_admin(current_user=Depends(get_current_user)):
    """Require admin role"""
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required",
        )
    return current_user
