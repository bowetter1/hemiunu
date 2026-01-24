"""Tenant routes"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel

from apex_server.shared.database import get_db
from apex_server.shared.dependencies import get_current_user
from apex_server.auth.models import User
from .service import TenantService

router = APIRouter(prefix="/tenants", tags=["tenants"])


class TenantResponse(BaseModel):
    id: str
    name: str
    slug: str
    max_concurrent_sprints: int
    worker_config: dict

    class Config:
        from_attributes = True


class UpdateWorkerConfigRequest(BaseModel):
    worker_config: dict


@router.get("/me", response_model=TenantResponse)
def get_my_tenant(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get current user's tenant"""
    service = TenantService(db)
    tenant = service.get_by_id(current_user.tenant_id)
    if not tenant:
        raise HTTPException(status_code=404, detail="Tenant not found")
    return TenantResponse(
        id=str(tenant.id),
        name=tenant.name,
        slug=tenant.slug,
        max_concurrent_sprints=tenant.max_concurrent_sprints,
        worker_config=tenant.worker_config
    )


@router.put("/me/workers", response_model=TenantResponse)
def update_worker_config(
    request: UpdateWorkerConfigRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update worker configuration (admin only)"""
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin only")

    service = TenantService(db)
    tenant = service.update_worker_config(current_user.tenant_id, request.worker_config)
    if not tenant:
        raise HTTPException(status_code=404, detail="Tenant not found")

    return TenantResponse(
        id=str(tenant.id),
        name=tenant.name,
        slug=tenant.slug,
        max_concurrent_sprints=tenant.max_concurrent_sprints,
        worker_config=tenant.worker_config
    )
