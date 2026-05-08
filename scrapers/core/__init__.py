from .authorization import (
    AuthorizationConfigurationError,
    AuthorizationStrategyResolver,
    AuthResolution,
)
from .base_source_scraper import BaseSourceScraper
from .contracts import (
    AuthorizationStrategy,
    PersistOutcome,
    RateLimitPolicy,
    ScrapeMode,
    ScrapeRunContext,
    SourceScrapedProduct,
)
from .github_adapter import GitHubSourceAdapter

__all__ = [
    "AuthResolution",
    "AuthorizationConfigurationError",
    "AuthorizationStrategyResolver",
    "AuthorizationStrategy",
    "BaseSourceScraper",
    "GitHubSourceAdapter",
    "PersistOutcome",
    "RateLimitPolicy",
    "ScrapeMode",
    "ScrapeRunContext",
    "SourceScrapedProduct",
]
