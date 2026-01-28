"""Auth routes"""
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel, EmailStr

from apex_server.shared.database import get_db
from apex_server.config import get_settings
from apex_server.shared.dependencies import get_current_user, get_current_admin
from apex_server.tenants.service import TenantService
from .service import AuthService
from .models import User

router = APIRouter(prefix="/auth", tags=["auth"])


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str
    name: str
    tenant_name: str  # Creates new tenant on register


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class UserResponse(BaseModel):
    id: str
    email: str
    name: str
    role: str
    tenant_id: str

    class Config:
        from_attributes = True


@router.post("/register", response_model=TokenResponse)
def register(request: RegisterRequest, db: Session = Depends(get_db)):
    """Register a new user and tenant"""
    auth_service = AuthService(db)
    tenant_service = TenantService(db)

    # Check if email exists
    if auth_service.get_by_email(request.email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )

    # Create tenant
    slug = request.tenant_name.lower().replace(" ", "-")
    if tenant_service.get_by_slug(slug):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Tenant name already taken"
        )

    tenant = tenant_service.create(name=request.tenant_name, slug=slug)

    # Create user as admin of the tenant
    user = auth_service.create_user(
        email=request.email,
        password=request.password,
        name=request.name,
        tenant_id=tenant.id,
        role="admin"
    )

    # Generate token
    token = auth_service.create_token(user.id, tenant.id)
    return TokenResponse(access_token=token)


@router.post("/login", response_model=TokenResponse)
def login(request: LoginRequest, db: Session = Depends(get_db)):
    """Login and get access token"""
    auth_service = AuthService(db)

    user = auth_service.authenticate(request.email, request.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password"
        )

    token = auth_service.create_token(user.id, user.tenant_id)
    return TokenResponse(access_token=token)


@router.post("/dev-token", response_model=TokenResponse)
def get_dev_token(db: Session = Depends(get_db)):
    """Get a dev token - creates or uses a default dev user"""
    settings = get_settings()
    if not settings.dev_token_enabled:
        raise HTTPException(status_code=403, detail="Dev token disabled")

    auth_service = AuthService(db)
    tenant_service = TenantService(db)

    dev_email = "dev@apex.local"
    user = auth_service.get_by_email(dev_email)

    if not user:
        # Create dev tenant and user
        tenant = tenant_service.get_by_slug("dev")
        if not tenant:
            tenant = tenant_service.create(name="Dev Tenant", slug="dev")

        user = auth_service.create_user(
            email=dev_email,
            password="dev123",
            name="Dev User",
            tenant_id=tenant.id,
            role="admin"
        )

    token = auth_service.create_token(user.id, user.tenant_id)
    return TokenResponse(access_token=token)


@router.get("/me", response_model=UserResponse)
def get_me(current_user = Depends(get_current_user)):
    """Get current user info"""
    return UserResponse(
        id=str(current_user.id),
        email=current_user.email,
        name=current_user.name,
        role=current_user.role,
        tenant_id=str(current_user.tenant_id)
    )


class ResetPasswordRequest(BaseModel):
    email: EmailStr
    new_password: str
    admin_key: str


@router.post("/admin/reset-password")
def reset_password(request: ResetPasswordRequest, db: Session = Depends(get_db)):
    """Admin endpoint to reset a user's password"""
    import os
    admin_key = os.environ.get("ADMIN_KEY", "")
    if not admin_key or request.admin_key != admin_key:
        raise HTTPException(status_code=403, detail="Invalid admin key")

    auth_service = AuthService(db)
    user = auth_service.get_by_email(request.email)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user.password_hash = auth_service.hash_password(request.new_password)
    db.commit()
    return {"status": "ok", "message": "Password updated"}


# --- Admin user-approval endpoints ---


@router.get("/admin/pending-users")
def list_pending_users(db: Session = Depends(get_db), admin=Depends(get_current_admin)):
    """List all users awaiting approval"""
    return db.query(User).filter(User.status == "pending").all()


@router.post("/admin/approve-user/{user_id}")
def approve_user(user_id: uuid.UUID, db: Session = Depends(get_db), admin=Depends(get_current_admin)):
    """Approve a pending user"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.status = "approved"
    db.commit()
    return {"status": "approved"}


@router.post("/admin/reject-user/{user_id}")
def reject_user(user_id: uuid.UUID, db: Session = Depends(get_db), admin=Depends(get_current_admin)):
    """Reject a pending user"""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    user.status = "rejected"
    db.commit()
    return {"status": "rejected"}
