"""Tags management endpoints.

Provides endpoints for listing tags, viewing individual tags, and updating tag
metadata (including the featured flag) for admin users.

Public endpoints:
  GET /api/tags         - list all tags with name and featured status
  GET /api/tags/{tag_id} - get a single tag by ID

Admin-only endpoints:
  PATCH /api/tags/{tag_id} - update a tag (e.g., set featured=true/false)
"""
import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from services.auth import get_current_user
from services.database import get_db

router = APIRouter(prefix="/api/tags", tags=["tags"])

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Pydantic models
# ---------------------------------------------------------------------------

class TagResponse(BaseModel):
    id: str
    name: str
    featured: bool


class TagUpdate(BaseModel):
    featured: Optional[bool] = None


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.get("", response_model=list[TagResponse])
async def list_tags(
    featured: Optional[bool] = None,
    db=Depends(get_db),
):
    """List all tags with their name and featured status.

    - Optional ``featured`` query parameter filters to only featured (or non-featured) tags.
    - Returns tags sorted alphabetically by name.
    """
    try:
        query = db.table("tags").select("id,name,featured").order("name")
        if featured is not None:
            query = query.eq("featured", featured)
        response = query.execute()
        rows = response.data or []
        # Ensure featured defaults to False when column is absent (e.g., older rows)
        for row in rows:
            if row.get("featured") is None:
                row["featured"] = False
        return rows
    except Exception as e:
        logger.error(f"[list_tags] Failed: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve tags")


@router.get("/{tag_id}", response_model=TagResponse)
async def get_tag(
    tag_id: str,
    db=Depends(get_db),
):
    """Get a single tag by ID."""
    try:
        response = db.table("tags").select("id,name,featured").eq("id", tag_id).limit(1).execute()
        if not response.data:
            raise HTTPException(status_code=404, detail="Tag not found")
        row = response.data[0]
        if row.get("featured") is None:
            row["featured"] = False
        return row
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[get_tag] Failed: {e}")
        raise HTTPException(status_code=500, detail="Failed to retrieve tag")


@router.patch("/{tag_id}", response_model=TagResponse)
async def update_tag(
    tag_id: str,
    body: TagUpdate,
    current_user: dict = Depends(get_current_user),
    db=Depends(get_db),
):
    """Update a tag (admin only).

    Currently supports updating the ``featured`` flag.
    """
    if current_user.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")

    # Verify tag exists
    existing = db.table("tags").select("id,name,featured").eq("id", tag_id).limit(1).execute()
    if not existing.data:
        raise HTTPException(status_code=404, detail="Tag not found")

    update_data = {}
    if body.featured is not None:
        update_data["featured"] = body.featured

    if not update_data:
        row = existing.data[0]
        if row.get("featured") is None:
            row["featured"] = False
        return row

    response = db.table("tags").update(update_data).eq("id", tag_id).execute()
    if not response.data:
        raise HTTPException(status_code=500, detail="Failed to update tag")

    row = response.data[0]
    if row.get("featured") is None:
        row["featured"] = False
    return row
