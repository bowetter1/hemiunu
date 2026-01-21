from sqlalchemy import Column, Integer, Numeric, String, Date, DateTime
from sqlalchemy.sql import func
from database import Base


class Expense(Base):
    __tablename__ = "expenses"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    amount = Column(Numeric(10, 2), nullable=False)  # Up to 99,999,999.99
    description = Column(String(255), nullable=False)
    category = Column(String(50), nullable=False)
    date = Column(Date, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())