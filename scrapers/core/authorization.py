from dataclasses import dataclass, field
from typing import Any

from .contracts import AuthorizationStrategy


class AuthorizationConfigurationError(RuntimeError):
    """Raised when source auth is required but not configured."""


@dataclass(slots=True)
class AuthResolution:
    strategy: AuthorizationStrategy
    headers: dict[str, str] = field(default_factory=dict)
    metadata: dict[str, Any] = field(default_factory=dict)


class AuthorizationStrategyResolver:
    """Resolve per-source auth configuration into a common shape.

    This class is intentionally small for phase-1 scaffolding.
    Runtime DB-backed resolution can be layered in phase-2.
    """

    def resolve(
        self,
        *,
        strategy: AuthorizationStrategy,
        access_token: str | None = None,
        static_headers: dict[str, str] | None = None,
        require_auth: bool = False,
    ) -> AuthResolution:
        if strategy == AuthorizationStrategy.NONE:
            if require_auth:
                raise AuthorizationConfigurationError("Auth is required but strategy is 'none'.")
            return AuthResolution(strategy=strategy)

        if strategy in (AuthorizationStrategy.BEARER_TOKEN, AuthorizationStrategy.OAUTH2_REFRESHABLE):
            if not access_token:
                raise AuthorizationConfigurationError(
                    f"Auth strategy '{strategy}' requires an access token."
                )
            return AuthResolution(
                strategy=strategy,
                headers={"Authorization": f"Bearer {access_token}"},
            )

        if strategy == AuthorizationStrategy.STATIC_HEADER:
            if not static_headers:
                raise AuthorizationConfigurationError(
                    "Auth strategy 'static_header' requires at least one header."
                )
            return AuthResolution(strategy=strategy, headers=static_headers)

        raise AuthorizationConfigurationError(f"Unsupported authorization strategy: {strategy}")
