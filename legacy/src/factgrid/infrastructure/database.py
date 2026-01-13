"""MongoDB database connection for FactGrid."""

from typing import Optional

from pymongo import MongoClient
from pymongo.collection import Collection
from pymongo.database import Database

from factgrid.infrastructure.config import Settings, get_settings


_client: Optional[MongoClient] = None


def get_client(settings: Optional[Settings] = None) -> MongoClient:
    """Get MongoDB client (singleton)."""
    global _client
    if _client is None:
        resolved = settings or get_settings()
        _client = MongoClient(resolved.mongo_uri, serverSelectionTimeoutMS=5000)
    return _client


def get_database(settings: Optional[Settings] = None) -> Database:
    """Get MongoDB database."""
    resolved = settings or get_settings()
    client = get_client(resolved)
    return client[resolved.mongo_db]


def get_collection(
    collection_name: str,
    settings: Optional[Settings] = None,
) -> Collection:
    """Get MongoDB collection."""
    db = get_database(settings)
    return db[collection_name]
