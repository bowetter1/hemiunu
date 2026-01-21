"""Auth service - JWT and password handling"""
import uuid
from datetime import datetime, timedelta
from typing import Optional

from jose import jwt, JWTError
from passlib.context import CryptContext
from sqlalchemy.orm import Session

from apex_server.config import get_settings
from .models import User

settings = get_settings()
pwd_context = CryptContext(schemes=["sha256_crypt"], deprecated="auto")


class AuthService:
    """Service for authentication operations"""

    def __init__(self, db: Session):
        self.db = db

    # Password handling
    @staticmethod
    def hash_password(password: str) -> str:
        """Hash a password"""
        return pwd_context.hash(password)

    @staticmethod
    def verify_password(plain: str, hashed: str) -> bool:
        """Verify a password against a hash"""
        return pwd_context.verify(plain, hashed)

    # JWT handling
    @staticmethod
    def create_token(user_id: uuid.UUID, tenant_id: uuid.UUID) -> str:
        """Create a JWT token"""
        expire = datetime.utcnow() + timedelta(minutes=settings.jwt_expire_minutes)
        payload = {
            "sub": str(user_id),
            "tenant": str(tenant_id),
            "exp": expire
        }
        return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)

    @staticmethod
    def decode_token(token: str) -> Optional[dict]:
        """Decode and validate a JWT token"""
        try:
            payload = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
            return payload
        except JWTError:
            return None

    # User operations
    def get_by_email(self, email: str) -> Optional[User]:
        """Get user by email"""
        return self.db.query(User).filter(User.email == email).first()

    def get_by_id(self, user_id: uuid.UUID) -> Optional[User]:
        """Get user by ID"""
        return self.db.query(User).filter(User.id == user_id).first()

    def create_user(
        self,
        email: str,
        password: str,
        name: str,
        tenant_id: uuid.UUID,
        role: str = "member"
    ) -> User:
        """Create a new user"""
        user = User(
            email=email,
            password_hash=self.hash_password(password),
            name=name,
            tenant_id=tenant_id,
            role=role
        )
        self.db.add(user)
        self.db.commit()
        self.db.refresh(user)
        return user

    def authenticate(self, email: str, password: str) -> Optional[User]:
        """Authenticate user by email and password"""
        user = self.get_by_email(email)
        if not user:
            return None
        if not self.verify_password(password, user.password_hash):
            return None
        return user
