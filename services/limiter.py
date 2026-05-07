"""Shared rate-limiter instance.

Importing the limiter from ``main`` would create a circular dependency because
``main`` imports from every router.  Instead, both ``main`` and any router that
needs rate-limiting import this module.
"""

from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
