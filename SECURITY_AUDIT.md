# Security Audit Report - a11yhood Backend API

**Audit Date:** December 27, 2025  
**Auditor:** AI Security Review  
**Scope:** Full backend codebase security assessment

## Executive Summary

This comprehensive security audit reviewed authentication, authorization, data protection, input validation, and infrastructure security. The application demonstrates good security practices overall, with several areas requiring immediate attention and recommended improvements.

**Critical Issues:** 2  (fixed)
**High Priority:** 5  (fixed)
**Medium Priority:** 8  
**Low Priority:** 4  
**Best Practices:** 6

---

## 🟡 Medium Priority Issues

### 8. Weak Default Secret Key

**Severity:** MEDIUM  
**File:** `config.py`  
**Line:** 40

**Issue:**
```python
SECRET_KEY: str = "dev-secret-key-change-in-production"
```

Default value is predictable and documented in code.

**Recommendation:**
```python
# config.py
SECRET_KEY: str = None  # Force explicit configuration

# Validation in startup
if not settings.SECRET_KEY:
    raise RuntimeError("SECRET_KEY must be set in environment variables")

if settings.SECRET_KEY == "dev-secret-key-change-in-production":
    if not settings.TEST_MODE:
        raise RuntimeError("Cannot use default SECRET_KEY in production")

# Generate secure key:
# python -c "import secrets; print(secrets.token_hex(32))"
```

### 9. CORS Configuration Accepts Extra Origins Without Validation

**Severity:** MEDIUM  
**File:** `main.py`  
**Lines:** 48-50

**Issue:**
```python
extra = os.getenv("CORS_EXTRA_ORIGINS", "")
if extra:
    origins.update(o.strip() for o in extra.split(",") if o.strip())
```

No validation of origin format or protocol. Could allow misconfiguration.

**Recommendation:**
```python
def validate_origin(origin: str) -> bool:
    """Validate CORS origin is a valid URL"""
    import re
    pattern = r'^https?://[\w\-]+(\.[\w\-]+)*(:\d+)?$'
    return bool(re.match(pattern, origin))

def get_cors_origins():
    origins = set()
    
    # ... existing code ...
    
    # Validate extra origins
    extra = os.getenv("CORS_EXTRA_ORIGINS", "")
    if extra:
        for origin in extra.split(","):
            origin = origin.strip()
            if origin and validate_origin(origin):
                origins.add(origin)
            elif origin:
                raise ValueError(f"Invalid CORS origin format: {origin}")
    
    # Never allow wildcard in production
    if "*" in origins and not settings.TEST_MODE:
        raise RuntimeError("Wildcard CORS origins not allowed in production")
    
    return list(origins)
```

### 10. No Password Policy or Account Lockout

**Severity:** MEDIUM  
**Issue:**
Using OAuth providers handles password security, but no protection against:
- Account enumeration via timing attacks
- Brute force on dev tokens
- Session hijacking

**Recommendation:**
```python
# Add account lockout tracking
# File: services/auth_security.py

from datetime import datetime, timedelta
from typing import Dict

# In-memory tracking (use Redis in production)
failed_attempts: Dict[str, list] = {}
locked_accounts: Dict[str, datetime] = {}

LOCKOUT_THRESHOLD = 5
LOCKOUT_DURATION = timedelta(minutes=15)
ATTEMPT_WINDOW = timedelta(minutes=5)

def record_failed_auth(identifier: str):
    """Record failed authentication attempt"""
    now = datetime.utcnow()
    
    # Clean old attempts
    if identifier in failed_attempts:
        failed_attempts[identifier] = [
            t for t in failed_attempts[identifier]
            if now - t < ATTEMPT_WINDOW
        ]
    else:
        failed_attempts[identifier] = []
    
    failed_attempts[identifier].append(now)
    
    # Lock account if threshold exceeded
    if len(failed_attempts[identifier]) >= LOCKOUT_THRESHOLD:
        locked_accounts[identifier] = now + LOCKOUT_DURATION
        log_security_event(
            event_type="ACCOUNT_LOCKED",
            user_id=identifier,
            severity="WARNING",
            details={"reason": "Too many failed login attempts"}
        )

def is_account_locked(identifier: str) -> bool:
    """Check if account is currently locked"""
    if identifier not in locked_accounts:
        return False
    
    if datetime.utcnow() > locked_accounts[identifier]:
        # Lockout expired
        del locked_accounts[identifier]
        return False
    
    return True

# Use in auth.py:
async def get_current_user(authorization: str = Header(None)):
    # ... existing code ...
    
    if settings.TEST_MODE and token.startswith("dev-token-"):
        user_id = token.replace("dev-token-", "").strip()
        
        # Check account lockout
        if is_account_locked(user_id):
            raise HTTPException(
                status_code=429,
                detail="Account temporarily locked due to suspicious activity"
            )
        
        # ... existing validation ...
        
        if not response.data:
            record_failed_auth(user_id)
            raise HTTPException(status_code=401, detail="Invalid user")
```

### 11. Sensitive Data Logging

**Severity:** MEDIUM  
**Files:** `test_ravelry_auth.py`, potential others

**Issue:**
Debug scripts may log sensitive information.

**Recommendation:**
```python
# Create logging filter
class SensitiveDataFilter(logging.Filter):
    """Filter to redact sensitive data from logs"""
    
    SENSITIVE_KEYS = {
        'password', 'secret', 'token', 'key', 'api_key',
        'authorization', 'auth', 'credential'
    }
    
    def filter(self, record):
        if hasattr(record, 'msg'):
            msg = str(record.msg).lower()
            for key in self.SENSITIVE_KEYS:
                if key in msg:
                    record.msg = record.msg.replace(
                        record.msg,
                        "[REDACTED - contains sensitive data]"
                    )
        return True

# Apply to all loggers
import logging
for handler in logging.root.handlers:
    handler.addFilter(SensitiveDataFilter())
```

### 12. No CSRF Protection

**Severity:** MEDIUM  
**Files:** All mutation endpoints

**Issue:**
No CSRF tokens for state-changing operations. Using cookies with credentials makes this necessary.

**Recommendation:**
```python
# Install fastapi-csrf-protect
# pip install fastapi-csrf-protect

from fastapi_csrf_protect import CsrfProtect
from fastapi_csrf_protect.exceptions import CsrfProtectError
from pydantic import BaseModel

class CsrfSettings(BaseModel):
    secret_key: str = settings.SECRET_KEY
    cookie_samesite: str = "strict"
    cookie_secure: bool = not settings.TEST_MODE

@CsrfProtect.load_config
def get_csrf_config():
    return CsrfSettings()

# Apply to mutation endpoints
@router.post("/api/products")
async def create_product(
    csrf_protect: CsrfProtect = Depends(),
    ...
):
    await csrf_protect.validate_csrf_in_cookies(request)
    # ... rest of code
```

### 13. Docker Container Runs as Root

**Severity:** MEDIUM  
**File:** `Dockerfile`  
**Lines:** 53-54

**Issue:**
```dockerfile
RUN useradd -m -u 1000 appuser && \
```

Good that non-root user is created, but not enforced with `USER` directive.

**Recommendation:**
```dockerfile
# After copying files
COPY . .
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Health check and CMD
```

### 14. No Dependency Vulnerability Scanning

**Severity:** MEDIUM  
**Issue:**
No automated security scanning for dependencies.

**Recommendation:**
```yaml
# .github/workflows/security.yml
name: Security Scan

on: [push, pull_request]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Run Snyk Security Scan
        uses: snyk/actions/python@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
      
      - name: Run Safety check
        run: |
          pip install safety
          safety check --json
      
      - name: Run Bandit
        run: |
          pip install bandit
          bandit -r . -f json -o bandit-report.json
```

### 15. Missing Security.txt

**Severity:** MEDIUM  
**Issue:**
No security policy or responsible disclosure process documented.

**Recommendation:**
```
# Create: .well-known/security.txt
Contact: security@a11yhood.com
Expires: 2026-12-31T23:59:59.000Z
Preferred-Languages: en
Canonical: https://a11yhood.com/.well-known/security.txt
Policy: https://a11yhood.com/security-policy
```

---

## 🔵 Low Priority Issues

### 16. Test Mode User IDs Are Predictable UUIDs

**Severity:** LOW  
**File:** `seed_test_users.py`

**Issue:**
Hardcoded UUIDs make accounts discoverable.

**Recommendation:**
Only matters if TEST_MODE accidentally enabled. Already covered by Critical Issue #2.

### 17. No API Versioning

**Severity:** LOW  
**Files:** All routers

**Issue:**
All endpoints at `/api/*` without version prefix makes breaking changes difficult.

**Recommendation:**
```python
# Use versioned prefixes
router = APIRouter(prefix="/api/v1/products", tags=["products"])
```

### 18. Missing Request ID Tracing

**Severity:** LOW  
**Issue:**
No request correlation IDs for debugging.

**Recommendation:**
```python
import uuid

@app.middleware("http")
async def add_request_id(request, call_next):
    request_id = str(uuid.uuid4())
    request.state.request_id = request_id
    
    response = await call_next(request)
    response.headers["X-Request-ID"] = request_id
    return response
```

### 19. No Database Connection Pooling Configuration

**Severity:** LOW  
**File:** `database_adapter.py`

**Issue:**
Default connection pool settings may not be optimal.

**Recommendation:**
```python
engine = create_engine(
    DATABASE_URL,
    pool_size=20,
    max_overflow=0,
    pool_pre_ping=True,
    pool_recycle=3600
)
```

---

## ✅ Security Best Practices (Already Implemented)

1. **Parameterized Queries** - Using SQLAlchemy and Supabase SDK prevents SQL injection
2. **HTTPS Enforcement** - CORS limited to HTTPS origins in production
3. **Authentication Required** - Most endpoints properly require authentication
4. **Role-Based Access Control** - Admin/moderator roles enforced server-side
5. **Ownership Validation** - Users can only modify their own resources
6. **Security Tests** - Comprehensive test suite in `tests/test_security.py`

---

## Remediation Priority

### Immediate (This Week)
1. ✅ Revoke and remove hardcoded OAuth credentials
2. ✅ Add TEST_MODE validation in startup
3. ✅ Implement error message sanitization
4. ✅ Add security headers middleware

### Short Term (This Month)
1. Implement rate limiting
2. Add XSS sanitization
3. Configure security logging
4. Add CSRF protection
5. Fix Docker USER directive

### Medium Term (This Quarter)
1. Set up dependency scanning
2. Implement account lockout
3. Add API versioning
4. Create security.txt
5. Add monitoring/alerting

---

## Testing Recommendations

```bash
# Run security tests
pytest tests/test_security.py -v

# Check for common vulnerabilities
bandit -r . -ll

# Scan dependencies
safety check

# Check for secrets in git history
trufflehog --regex --entropy=False .

# OWASP ZAP scan
docker run -t owasp/zap2docker-stable zap-baseline.py -t https://localhost:8000
```

---

## Compliance Notes

- **GDPR**: Ensure user data deletion capabilities
- **WCAG**: Already focused on accessibility
- **OWASP Top 10**: Most issues covered, XSS needs attention
- **PCI DSS**: N/A (no payment processing)

---

## Conclusion

The a11yhood backend demonstrates solid foundational security practices with proper authentication, authorization, and testing. However, **immediate action is required** to address the critical issues:

1. Remove hardcoded secrets from version control
2. Add runtime validation to prevent TEST_MODE in production

Following the remediation plan will significantly improve the security posture and protect user data.

**Next Steps:**
1. Review this audit with the team
2. Create tickets for each finding
3. Implement critical fixes immediately
4. Schedule regular security reviews
5. Consider third-party penetration testing before launch
