"""Tenant service"""
import uuid
from typing import Optional

from sqlalchemy.orm import Session

from .models import Tenant


class TenantService:
    """Service for tenant operations"""

    def __init__(self, db: Session):
        self.db = db

    def create(self, name: str, slug: str) -> Tenant:
        """Create a new tenant"""
        tenant = Tenant(
            name=name,
            slug=slug,
            worker_config={"chef": "opus", "backend": "opus", "frontend": "opus"}
        )
        self.db.add(tenant)
        self.db.commit()
        self.db.refresh(tenant)
        return tenant

    def get_by_id(self, tenant_id: uuid.UUID) -> Optional[Tenant]:
        """Get tenant by ID"""
        return self.db.query(Tenant).filter(Tenant.id == tenant_id).first()

    def get_by_slug(self, slug: str) -> Optional[Tenant]:
        """Get tenant by slug"""
        return self.db.query(Tenant).filter(Tenant.slug == slug).first()

    def update_worker_config(self, tenant_id: uuid.UUID, config: dict) -> Optional[Tenant]:
        """Update worker configuration"""
        tenant = self.get_by_id(tenant_id)
        if tenant:
            tenant.worker_config = config
            self.db.commit()
            self.db.refresh(tenant)
        return tenant
