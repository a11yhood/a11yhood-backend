import pytest
from fastapi import HTTPException

from routers.blog_posts import _validate_image_size


def test_validate_image_size_rejects_missing_data_url_comma():
    with pytest.raises(HTTPException) as exc_info:
        _validate_image_size("data:image/png;base64")
    assert exc_info.value.status_code == 400
    detail = exc_info.value.detail
    assert detail["code"] == "invalid_data_url"
    assert detail["field"] == "header_image"


def test_validate_image_size_rejects_over_2mb_payload():
    oversized_b64 = "A" * (int((2 * 1024 * 1024) * 4 / 3) + 8)
    with pytest.raises(HTTPException) as exc_info:
        _validate_image_size(f"data:image/png;base64,{oversized_b64}", field_name="content image")
    assert exc_info.value.status_code == 413
    detail = exc_info.value.detail
    assert detail["code"] == "image_too_large"
    assert detail["field"] == "content image"
    assert detail["max_bytes"] == 2 * 1024 * 1024


def test_validate_image_size_allows_small_payload():
    _validate_image_size("data:image/png;base64,iVBORw0KGgo=")
