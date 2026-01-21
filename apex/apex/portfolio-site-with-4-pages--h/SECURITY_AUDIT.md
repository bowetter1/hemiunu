# Security Audit Report

## Status: VULNERABILITIES_FOUND

## Summary
The application is a static portfolio site served via FastAPI. As there is no database or backend processing of user input, the attack surface is minimal. However, standard security headers are missing, and dependencies should be kept up to date.

## Findings

### [MEDIUM] Missing HTTP Security Headers
- **File:** `main.py`
- **Vulnerability:** The application does not set standard security headers, leaving it potentially vulnerable to clickjacking, MIME-sniffing, and XSS if scripts are injected.
- **Fix:** Add middleware to set `Content-Security-Policy`, `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, and `Strict-Transport-Security` (in production).
- **Example Fix:**
  ```python
  from fastapi.middleware.trustedhost import TrustedHostMiddleware
  from starlette.middleware.base import BaseHTTPMiddleware
  
  # Custom middleware to add headers
  class SecurityHeadersMiddleware(BaseHTTPMiddleware):
      async def dispatch(self, request, call_next):
          response = await call_next(request)
          response.headers["Content-Security-Policy"] = "default-src 'self'; script-src 'self' 'unsafe-inline' https://unpkg.com https://fonts.googleapis.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com;"
          response.headers["X-Content-Type-Options"] = "nosniff"
          response.headers["X-Frame-Options"] = "DENY"
          response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
          return response
  
  app.add_middleware(SecurityHeadersMiddleware)
  ```

### [LOW] Outdated Jinja2 Version
- **File:** `requirements.txt`
- **Vulnerability:** Using `jinja2==3.1.2`. Versions < 3.1.3 have a potential XSS vulnerability in the `xmlattr` filter (CVE-2024-22195). While `xmlattr` is not currently used, it is best practice to update.
- **Fix:** Update `requirements.txt` to `jinja2>=3.1.3`.

### [LOW] Missing CSRF Protection (Future Proofing)
- **File:** `templates/contact.html`
- **Vulnerability:** The contact form currently has no backend handler, so CSRF is not an immediate threat. However, if a POST endpoint is added, it will be vulnerable without a CSRF token.
- **Fix:** Ensure any future form handlers implement CSRF protection (e.g., using `starsessions` or a custom dependency).

### [INFO] Server Header Disclosure
- **File:** `main.py` (deployment configuration)
- **Vulnerability:** Uvicorn and FastAPI default behavior may reveal server versions in the `Server` response header, which can aid attackers in reconnaissance.
- **Fix:** Run Uvicorn with `--no-server-header` or strip the header in middleware.

## Positive Findings
- ✅ **No SQL Injection:** No database is used.
- ✅ **No Reflected XSS:** Templates do not render user-controlled input.
- ✅ **No DOM XSS:** JavaScript logic uses safe DOM manipulation.
- ✅ **Minimal Attack Surface:** No authentication, sessions, or sensitive data handling.
