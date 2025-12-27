"""Test startup security validation.

Ensures that TEST_MODE and default SECRET_KEY are rejected in production-like environments.
"""
import pytest
import os
from unittest.mock import patch


def test_test_mode_rejected_in_production_with_supabase():
    """TEST_MODE should be rejected when production Supabase URL is detected"""
    with patch.dict(os.environ, {
        "TEST_MODE": "true",
        "SUPABASE_URL": "https://myproject.supabase.co",
        "SUPABASE_KEY": "real-key",
    }, clear=False):
        # Reload config to pick up env changes
        from importlib import reload
        import config
        reload(config)
        
        # Try to start app
        with pytest.raises(RuntimeError, match="TEST_MODE=true in production"):
            from main import app
            # Trigger startup event
            import asyncio
            from main import validate_security_configuration
            asyncio.run(validate_security_configuration())


def test_test_mode_rejected_in_production_with_production_url():
    """TEST_MODE should be rejected when PRODUCTION_URL is set"""
    with patch.dict(os.environ, {
        "TEST_MODE": "true",
        "PRODUCTION_URL": "https://a11yhood.com",
    }, clear=False):
        from importlib import reload
        import config
        reload(config)
        
        with pytest.raises(RuntimeError, match="TEST_MODE=true in production"):
            import asyncio
            from main import validate_security_configuration
            asyncio.run(validate_security_configuration())


def test_test_mode_rejected_with_environment_variable():
    """TEST_MODE should be rejected when ENVIRONMENT=production"""
    with patch.dict(os.environ, {
        "TEST_MODE": "true",
        "ENVIRONMENT": "production",
    }, clear=False):
        from importlib import reload
        import config
        reload(config)
        
        with pytest.raises(RuntimeError, match="TEST_MODE=true in production"):
            import asyncio
            from main import validate_security_configuration
            asyncio.run(validate_security_configuration())


def test_default_secret_key_rejected_in_production():
    """Default SECRET_KEY should be rejected in production"""
    with patch.dict(os.environ, {
        "SECRET_KEY": "dev-secret-key-change-in-production",
        "SUPABASE_URL": "https://myproject.supabase.co",
        "TEST_MODE": "false",
    }, clear=False):
        from importlib import reload
        import config
        reload(config)
        
        with pytest.raises(RuntimeError, match="Default SECRET_KEY in production"):
            import asyncio
            from main import validate_security_configuration
            asyncio.run(validate_security_configuration())


def test_short_secret_key_rejected_in_production():
    """Short SECRET_KEY should be rejected in production"""
    with patch.dict(os.environ, {
        "SECRET_KEY": "short",
        "SUPABASE_URL": "https://myproject.supabase.co",
        "TEST_MODE": "false",
    }, clear=False):
        from importlib import reload
        import config
        reload(config)
        
        with pytest.raises(RuntimeError, match="SECRET_KEY too short"):
            import asyncio
            from main import validate_security_configuration
            asyncio.run(validate_security_configuration())


def test_test_mode_allowed_in_development():
    """TEST_MODE should be allowed when no production indicators present"""
    with patch.dict(os.environ, {
        "TEST_MODE": "true",
        "SUPABASE_URL": "https://dummy.supabase.co",
        "PRODUCTION_URL": "",
        "ENVIRONMENT": "development",
    }, clear=False):
        from importlib import reload
        import config
        reload(config)
        
        # Should not raise
        import asyncio
        from main import validate_security_configuration
        asyncio.run(validate_security_configuration())


def test_production_with_valid_config_succeeds():
    """Production with proper SECRET_KEY should work"""
    with patch.dict(os.environ, {
        "TEST_MODE": "false",
        "SECRET_KEY": "a" * 64,  # Long secure key
        "SUPABASE_URL": "https://myproject.supabase.co",
        "ENVIRONMENT": "production",
    }, clear=False):
        from importlib import reload
        import config
        reload(config)
        
        # Should not raise
        import asyncio
        from main import validate_security_configuration
        asyncio.run(validate_security_configuration())
