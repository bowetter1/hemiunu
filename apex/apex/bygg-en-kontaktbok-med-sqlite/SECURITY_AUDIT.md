# Security Audit Report

## Status: VULNERABILITIES_FOUND

## Summary
The application is **secure against common implementation vulnerabilities** like SQL Injection and XSS due to the proper use of SQLAlchemy ORM and robust HTML escaping in JavaScript. However, it lacks **authentication and authorization**, meaning anyone with network access to the API can read, modify, or delete all data.

## Findings

### [HIGH] Missing Authentication & Authorization
- **Vulnerability:** The API endpoints (`/contacts`) are open to the public. There is no login mechanism or access control.
- **Location:** `main.py` (all endpoints)
- **Impact:** If deployed to a public URL (like Railway), anyone who guesses the URL can access and manipulate user data.
- **Fix:** Implement a user model and authentication (e.g., OAuth2 with JWT) and protect endpoints with `Depends(get_current_user)`.

### [MEDIUM] Missing Rate Limiting
- **Vulnerability:** No limit on the number of requests a client can make.
- **Location:** `main.py`
- **Impact:** An attacker could flood the API with requests (DoS), filling the database or exhausting server resources.
- **Fix:** Use a library like `slowapi` to add decorators like `@limiter.limit("5/minute")` to write-heavy endpoints.

### [LOW] Unconstrained Database String Limits
- **Vulnerability:** The API accepts strings of arbitrary length (limited only by server payload limits), but the database schema implies limits (VARCHAR 100).
- **Location:** `main.py` (Pydantic models) vs `PLAN.md` (Schema)
- **Impact:** Sending extremely long strings could cause database errors or fill up storage.
- **Fix:** Add `max_length` to Pydantic models:
  ```python
  class ContactBase(BaseModel):
      name: str = Field(..., max_length=100)
      # ...
  ```

### [LOW] Missing Security Headers
- **Vulnerability:** Missing headers like `Content-Security-Policy`, `X-Frame-Options`, etc.
- **Location:** `main.py` / `templates/index.html`
- **Impact:** Reduced protection against advanced client-side attacks (e.g., clickjacking, loading malicious external scripts).
- **Fix:** Use `fastapi.middleware.cors.CORSMiddleware` (if needed) and/or a specialized middleware to set security headers. For CSP, add a `<meta>` tag or send it from the server.

## Positive Findings (Secure)
- ✅ **SQL Injection:** Protected via SQLAlchemy ORM.
- ✅ **XSS:** Protected via `escapeHtml` utility in `main.js`.
- ✅ **Secrets:** No hardcoded secrets found; `DATABASE_URL` is environment-aware.
