from sqlalchemy import Column, Integer, String, Text, DECIMAL
from database import Base

class Product(Base):
    __tablename__ = "products"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    description = Column(Text)
    price = Column(DECIMAL(10, 2))
    category = Column(String, index=True)
    image_url = Column(String)
    stock = Column(Integer, default=0)
