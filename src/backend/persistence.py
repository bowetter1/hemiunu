import aiosqlite
import asyncio
import logging
from typing import List, Dict, Any, Optional
from datetime import datetime
import uuid

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

DB_PATH = "game.db"

class PersistenceManager:
    def __init__(self, db_path: str = DB_PATH):
        self.db_path = db_path

    async def init_db(self):
        """Initialize the database tables."""
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute("""
                CREATE TABLE IF NOT EXISTS pyramid_blocks (
                    id TEXT PRIMARY KEY,
                    x INTEGER,
                    y INTEGER,
                    z INTEGER,
                    type TEXT,
                    created_at TIMESTAMP
                )
            """)
            await db.execute("""
                CREATE TABLE IF NOT EXISTS user_stones (
                    user_id TEXT PRIMARY KEY,
                    stones INTEGER
                )
            """)
            await db.commit()
            logger.info("Database initialized.")

    async def save_block(self, block_data: Dict[str, Any]):
        """Save a newly placed block to the database."""
        block_id = str(uuid.uuid4())
        created_at = datetime.utcnow()
        
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute(
                "INSERT INTO pyramid_blocks (id, x, y, z, type, created_at) VALUES (?, ?, ?, ?, ?, ?)",
                (block_id, block_data['x'], block_data['y'], block_data['z'], block_data['type'], created_at)
            )
            await db.commit()

    async def get_all_blocks(self) -> List[Dict[str, Any]]:
        """Retrieve all blocks from the database."""
        async with aiosqlite.connect(self.db_path) as db:
            db.row_factory = aiosqlite.Row
            async with db.execute("SELECT x, y, z, type FROM pyramid_blocks") as cursor:
                rows = await cursor.fetchall()
                return [dict(row) for row in rows]

    async def clear_all_blocks(self) -> None:
        """Remove all blocks from the database."""
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute("DELETE FROM pyramid_blocks")
            await db.commit()

    async def update_user_stones(self, user_id: str, stones: int):
        """Update or insert the stone count for a user."""
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute(
                "INSERT OR REPLACE INTO user_stones (user_id, stones) VALUES (?, ?)",
                (user_id, stones)
            )
            await db.commit()

    async def get_user_stones(self, user_id: str) -> Optional[int]:
        """Get the stone count for a specific user."""
        async with aiosqlite.connect(self.db_path) as db:
            async with db.execute("SELECT stones FROM user_stones WHERE user_id = ?", (user_id,)) as cursor:
                row = await cursor.fetchone()
                if row:
                    return row[0]
                return None
    
    async def get_all_user_stones(self) -> Dict[str, int]:
        """Retrieve all user stone counts (for initialization)."""
        async with aiosqlite.connect(self.db_path) as db:
            async with db.execute("SELECT user_id, stones FROM user_stones") as cursor:
                rows = await cursor.fetchall()
                return {row[0]: row[1] for row in rows}
