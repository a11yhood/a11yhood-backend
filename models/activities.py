"""
User activity models for tracking user actions.
"""
from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class UserActivityCreate(BaseModel):
    """Request model for creating user activity"""
    user_id: str
    type: str  # 'product_submit' | 'rating' | 'discussion' | 'tag'
    product_id: Optional[str] = None
    timestamp: datetime
    metadata: Optional[dict] = None


class UserActivityResponse(BaseModel):
    """Response model for user activity"""
    id: str
    user_id: str
    type: str
    product_id: Optional[str] = None
    timestamp: datetime
    created_at: Optional[datetime] = None
    metadata: Optional[dict] = None
