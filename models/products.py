
from pydantic import BaseModel, ConfigDict, Field, HttpUrl, field_validator

from models.product_urls import ProductUrlResponse
from services.timestamps import ApiTimestamp, OptionalApiTimestamp


def _validate_image_url_field(v: object) -> str | None:
    """Accept an HTTP(S) URL or a base-64 data URL; reject anything else."""
    if v is None:
        return None
    s = str(v).strip()
    if not s:
        return None
    # Allow data URLs produced by the image-upload endpoint
    if s.lower().startswith("data:"):
        return s
    # Validate as a proper HTTP/HTTPS URL via Pydantic's HttpUrl
    HttpUrl(s)
    return s


class ProductBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    description: str | None = None
    source: str | None = None  # Source platform (user-submitted, scraped-ravelry, etc.)
    source_url: HttpUrl | None = None  # URL to the source product
    type: str | None = None  # Product type/category (e.g., Knitting, 3D Printed, Software)
    image_url: str | None = None  # HTTP(S) URL or base-64 data URL
    image_alt: str | None = None
    external_id: str | None = None  # ID from external source
    tags: list[str] | None = Field(default_factory=list)
    source_last_updated: OptionalApiTimestamp = None
    matched_search_terms: list[str] | None = Field(
        default_factory=list
    )  # Search terms/categories that matched

    @field_validator("image_url", mode="before")
    @classmethod
    def validate_image_url(cls, v: object) -> str | None:
        return _validate_image_url_field(v)


class ProductCreate(ProductBase):
    pass


class ProductUpdate(BaseModel):
    name: str | None = Field(None, min_length=1, max_length=255)
    description: str | None = None
    source: str | None = None
    source_url: HttpUrl | None = None
    type: str | None = None
    image_url: str | None = None  # HTTP(S) URL or base-64 data URL
    image_alt: str | None = None
    external_id: str | None = None
    tags: list[str] | None = None
    source_last_updated: OptionalApiTimestamp = None
    matched_search_terms: list[str] | None = None

    @field_validator("image_url", mode="before")
    @classmethod
    def validate_image_url(cls, v: object) -> str | None:
        return _validate_image_url_field(v)


class ProductResponse(ProductBase):
    id: str
    slug: str
    created_by: str | None = None
    created_at: ApiTimestamp
    updated_at: ApiTimestamp
    banned: bool | None = None
    banned_reason: str | None = None
    banned_by: str | None = None
    banned_at: OptionalApiTimestamp = None
    average_rating: float | None = None
    rating_count: int = 0
    display_rating: float | None = None
    source_rating: float | None = None
    source_rating_count: int | None = None
    source_last_updated: OptionalApiTimestamp = None
    computed_rating: float | None = (
        None  # Computed display rating (PostgreSQL trigger or manual in tests)
    )
    stars: int | None = None
    urls: list[ProductUrlResponse] = Field(default_factory=list)
    editor_ids: list[str] = Field(default_factory=list)
    matched_search_terms: list[str] = Field(default_factory=list)

    model_config = ConfigDict(from_attributes=True)
