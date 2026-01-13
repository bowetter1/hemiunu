"""Repository for storing and retrieving headlines and stories from MongoDB."""

import logging
from datetime import datetime
from typing import List, Optional, Dict, Any

from pymongo.collection import Collection

from factgrid.infrastructure import get_settings, get_collection
from factgrid.domain.research.models import RawHeadline, ResearchedStory

logger = logging.getLogger(__name__)


class HeadlineRepository:
    """Repository for raw headlines from NewsAPI."""

    def __init__(self, collection: Optional[Collection] = None):
        if collection is None:
            settings = get_settings()
            self.collection = get_collection(settings.mongo_headlines_collection)
        else:
            self.collection = collection

    def save(self, headline: RawHeadline) -> str:
        """Save a headline to MongoDB. Returns the headline ID."""
        doc = headline.to_dict()
        self.collection.update_one(
            {"_id": doc["_id"]},
            {"$set": doc},
            upsert=True
        )
        logger.debug("Saved headline: %s", headline.id)
        return headline.id

    def save_many(self, headlines: List[RawHeadline]) -> int:
        """Save multiple headlines. Returns count of saved headlines."""
        if not headlines:
            return 0

        # Use bulk upsert
        from pymongo import UpdateOne
        operations = [
            UpdateOne(
                {"_id": h.id},
                {"$set": h.to_dict()},
                upsert=True
            )
            for h in headlines
        ]
        result = self.collection.bulk_write(operations)
        saved = result.upserted_count + result.modified_count
        logger.info("Saved %d headlines", saved)
        return saved

    def get_by_id(self, headline_id: str) -> Optional[RawHeadline]:
        """Get a headline by ID."""
        doc = self.collection.find_one({"_id": headline_id})
        if doc:
            return RawHeadline.from_dict(doc)
        return None

    def get_unprocessed(self, limit: int = 10) -> List[RawHeadline]:
        """Get unprocessed headlines for research."""
        docs = self.collection.find(
            {"processed": False}
        ).sort("fetched_at", -1).limit(limit)
        return [RawHeadline.from_dict(doc) for doc in docs]

    def get_recent(self, hours: int = 24, limit: int = 50) -> List[RawHeadline]:
        """Get recent headlines from the last N hours."""
        from datetime import timedelta
        cutoff = datetime.utcnow() - timedelta(hours=hours)
        docs = self.collection.find(
            {"fetched_at": {"$gte": cutoff}}
        ).sort("fetched_at", -1).limit(limit)
        return [RawHeadline.from_dict(doc) for doc in docs]

    def mark_processed(self, headline_id: str, story_id: str) -> bool:
        """Mark a headline as processed and link to story."""
        result = self.collection.update_one(
            {"_id": headline_id},
            {"$set": {"processed": True, "story_id": story_id}}
        )
        return result.modified_count > 0

    def count(self, processed: Optional[bool] = None) -> int:
        """Count headlines, optionally filtered by processed status."""
        query = {}
        if processed is not None:
            query["processed"] = processed
        return self.collection.count_documents(query)


class StoryRepository:
    """Repository for researched stories."""

    def __init__(self, collection: Optional[Collection] = None):
        if collection is None:
            settings = get_settings()
            self.collection = get_collection(settings.mongo_stories_collection)
        else:
            self.collection = collection

    def save(self, story: ResearchedStory) -> str:
        """Save a story to MongoDB. Returns the story ID."""
        doc = story.to_dict()
        doc["updated_at"] = datetime.utcnow()

        # Check if exists for versioning
        existing = self.collection.find_one({"_id": story.id})
        if existing:
            doc["version"] = existing.get("version", 0) + 1

        self.collection.update_one(
            {"_id": doc["_id"]},
            {"$set": doc},
            upsert=True
        )
        logger.info("Saved story: %s (v%d)", story.id, doc.get("version", 1))
        return story.id

    def get_by_id(self, story_id: str) -> Optional[ResearchedStory]:
        """Get a story by ID."""
        doc = self.collection.find_one({"_id": story_id})
        if doc:
            return ResearchedStory.from_dict(doc)
        return None

    def get_recent(self, limit: int = 20) -> List[ResearchedStory]:
        """Get most recent stories."""
        docs = self.collection.find().sort("created_at", -1).limit(limit)
        return [ResearchedStory.from_dict(doc) for doc in docs]

    def get_all(self, limit: int = 100) -> List[ResearchedStory]:
        """Get all stories (with limit)."""
        docs = self.collection.find().sort("updated_at", -1).limit(limit)
        return [ResearchedStory.from_dict(doc) for doc in docs]

    def delete(self, story_id: str) -> bool:
        """Delete a story by ID."""
        result = self.collection.delete_one({"_id": story_id})
        return result.deleted_count > 0

    def count(self) -> int:
        """Count total stories."""
        return self.collection.count_documents({})

    def search_by_title(self, query: str, limit: int = 10) -> List[ResearchedStory]:
        """Search stories by title (case-insensitive)."""
        docs = self.collection.find(
            {"title": {"$regex": query, "$options": "i"}}
        ).sort("created_at", -1).limit(limit)
        return [ResearchedStory.from_dict(doc) for doc in docs]
