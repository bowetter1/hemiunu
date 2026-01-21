"""Tenant domain"""
from .models import Tenant
from .service import TenantService

__all__ = ["Tenant", "TenantService"]
