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
            await db.execute("""
                CREATE TABLE IF NOT EXISTS usernames (
                    user_id TEXT PRIMARY KEY,
                    username TEXT
                )
            """)
            await db.execute("""
                CREATE TABLE IF NOT EXISTS user_stats (
                    user_id TEXT PRIMARY KEY,
                    blocks_placed INTEGER
                )
            """)
            await db.execute("""
                CREATE TABLE IF NOT EXISTS user_achievements (
                    user_id TEXT,
                    achievement_id TEXT,
                    unlocked_at TIMESTAMP,
                    PRIMARY KEY (user_id, achievement_id)
                )
            """)
            await db.execute("""
                CREATE TABLE IF NOT EXISTS user_placed_types (
                    user_id TEXT,
                    block_type TEXT,
                    PRIMARY KEY (user_id, block_type)
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

    async def update_user_stats(self, user_id: str, blocks_placed: int):
        """Update or insert the blocks placed count for a user."""
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute(
                "INSERT OR REPLACE INTO user_stats (user_id, blocks_placed) VALUES (?, ?)",
                (user_id, blocks_placed)
            )
            await db.commit()

    async def get_all_user_stats(self) -> Dict[str, int]:
        """Retrieve all user stats (blocks placed) for initialization."""
        async with aiosqlite.connect(self.db_path) as db:
            async with db.execute("SELECT user_id, blocks_placed FROM user_stats") as cursor:
                rows = await cursor.fetchall()
                return {row[0]: row[1] for row in rows}

    async def save_username(self, user_id: str, username: str) -> None:
        """Update or insert the username for a user."""
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute(
                "INSERT OR REPLACE INTO usernames (user_id, username) VALUES (?, ?)",
                (user_id, username)
            )
            await db.commit()

    async def get_username(self, user_id: str) -> Optional[str]:
        """Get the username for a specific user."""
        async with aiosqlite.connect(self.db_path) as db:
            async with db.execute("SELECT username FROM usernames WHERE user_id = ?", (user_id,)) as cursor:
                row = await cursor.fetchone()
                if row:
                    return row[0]
                return None

    async def get_all_usernames(self) -> Dict[str, str]:
        """Retrieve all usernames (for initialization)."""
        async with aiosqlite.connect(self.db_path) as db:
            async with db.execute("SELECT user_id, username FROM usernames") as cursor:
                rows = await cursor.fetchall()
                return {row[0]: row[1] for row in rows}

    async def save_achievement(self, user_id: str, achievement_id: str):
        """Record an unlocked achievement."""
        unlocked_at = datetime.utcnow()
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute(
                "INSERT OR IGNORE INTO user_achievements (user_id, achievement_id, unlocked_at) VALUES (?, ?, ?)",
                (user_id, achievement_id, unlocked_at)
            )
            await db.commit()

    async def get_user_achievements(self, user_id: str) -> List[str]:
        """Get list of achievement IDs unlocked by user."""
        async with aiosqlite.connect(self.db_path) as db:
            async with db.execute("SELECT achievement_id FROM user_achievements WHERE user_id = ?", (user_id,)) as cursor:
                rows = await cursor.fetchall()
                return [row[0] for row in rows]
    
    async def get_all_user_achievements(self) -> Dict[str, List[str]]:
        """Retrieve all achievements for all users (for initialization)."""
        async with aiosqlite.connect(self.db_path) as db:
            async with db.execute("SELECT user_id, achievement_id FROM user_achievements") as cursor:
                rows = await cursor.fetchall()
                result = {}
                for user_id, achievement_id in rows:
                    if user_id not in result:
                        result[user_id] = []
                    result[user_id].append(achievement_id)
                return result

    async def save_user_placed_type(self, user_id: str, block_type: str):
        """Record that a user has placed a specific block type."""
        async with aiosqlite.connect(self.db_path) as db:
            await db.execute(
                "INSERT OR IGNORE INTO user_placed_types (user_id, block_type) VALUES (?, ?)",
                (user_id, block_type)
            )
            await db.commit()

    async def get_user_placed_types(self, user_id: str) -> List[str]:
        """Get list of block types placed by user."""
        async with aiosqlite.connect(self.db_path) as db:
            async with db.execute("SELECT block_type FROM user_placed_types WHERE user_id = ?", (user_id,)) as cursor:
                rows = await cursor.fetchall()
                return [row[0] for row in rows]

    async def get_all_user_placed_types(self) -> Dict[str, set]:
        """Retrieve all placed types for all users."""
        async with aiosqlite.connect(self.db_path) as db:
            async with db.execute("SELECT user_id, block_type FROM user_placed_types") as cursor:
                rows = await cursor.fetchall()
                result = {}
                for user_id, block_type in rows:
                    if user_id not in result:
                        result[user_id] = set()
                    result[user_id].add(block_type)
                return result
