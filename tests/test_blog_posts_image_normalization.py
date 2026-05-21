from routers.blog_posts import _normalize_image_string


def test_normalize_image_string_keeps_api_images_path():
    src = "/api/images/65b38b8f-edea-44f4-894c-171842036dd5"
    assert _normalize_image_string(src) == src


def test_normalize_image_string_keeps_data_url():
    src = "data:image/png;base64,iVBORw0KGgo="
    assert _normalize_image_string(src) == src


def test_normalize_image_string_wraps_raw_base64():
    src = "iVBORw0KGgo="
    assert _normalize_image_string(src) == "data:image/png;base64,iVBORw0KGgo="
