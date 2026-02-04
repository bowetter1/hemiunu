# Supabase Integration

Supabase tillhandahåller Postgres-databas, autentisering (email + OAuth), storage och realtime för Apex-projekt.

## CLI

```bash
# Login
supabase login --token sbp_...

# Lista projekt
supabase projects list

# Hämta API-nycklar
supabase projects api-keys --project-ref <ref-id>
```

## Nycklar

Varje Supabase-projekt har dessa nycklar:

| Nyckel | Användning |
|--------|-----------|
| `anon` | Klient-sidan, säkert att exponera (RLS skyddar data) |
| `service_role` | Server-sidan, full access, **aldrig i klient-kod** |
| `NEXT_PUBLIC_SUPABASE_URL` | `https://<ref>.supabase.co` |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | = anon-nyckeln |

## Auth Setup

### Email/Password (standard)
Fungerar direkt utan extra konfiguration.

### Stänga av email-verifiering (test)
```bash
curl -X PATCH \
  -H "Authorization: Bearer sbp_..." \
  -H "Content-Type: application/json" \
  -d '{"mailer_autoconfirm": true}' \
  "https://api.supabase.com/v1/projects/<ref>/config/auth"
```

### Google OAuth
Kräver Google Cloud Console credentials:

1. Skapa OAuth 2.0 Client ID i [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Authorized redirect URI: `https://<ref>.supabase.co/auth/v1/callback`
3. Aktivera i Supabase:
```bash
curl -X PATCH \
  -H "Authorization: Bearer sbp_..." \
  -H "Content-Type: application/json" \
  -d '{
    "external_google_enabled": true,
    "external_google_client_id": "<google-client-id>",
    "external_google_secret": "<google-client-secret>"
  }' \
  "https://api.supabase.com/v1/projects/<ref>/config/auth"
```

### Klient-kod (Next.js)

**Login med email:**
```typescript
const { error } = await supabase.auth.signInWithPassword({
  email,
  password,
});
```

**Login med Google:**
```typescript
const { error } = await supabase.auth.signInWithOAuth({
  provider: "google",
  options: {
    redirectTo: `${window.location.origin}/auth/callback`,
  },
});
```

**OAuth callback route** (`app/auth/callback/route.ts`):
```typescript
import { createClient } from "@/lib/supabase/server";
import { NextResponse } from "next/server";

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");
  const next = searchParams.get("next") ?? "/dashboard";

  if (code) {
    const supabase = await createClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) {
      return NextResponse.redirect(`${origin}${next}`);
    }
  }

  return NextResponse.redirect(`${origin}/auth/error`);
}
```

## Admin API

### Lista användare
```bash
curl -H "apikey: <service_role_key>" \
  -H "Authorization: Bearer <service_role_key>" \
  "https://<ref>.supabase.co/auth/v1/admin/users"
```

### Auth-konfiguration
```bash
# Läs alla auth-settings
curl -H "Authorization: Bearer sbp_..." \
  "https://api.supabase.com/v1/projects/<ref>/config/auth"

# Filtrera Google-relaterade
curl ... | python3 -c "
import json, sys
data = json.load(sys.stdin)
for k,v in sorted(data.items()):
    if 'GOOGLE' in k.upper() or 'EXTERNAL' in k.upper():
        print(f'{k}: {v}')
"
```

## Next.js Integration

### proxy.ts (Next.js 16)
Next.js 16 använder `proxy.ts` istället för `middleware.ts`. Template-repot (`Barty-Bart/nextjs-supabase-shadcn-boilerplate`) har en komplett `proxy.ts` som:
- Refreshar Supabase-sessioner automatiskt
- Skyddar `/dashboard/*` routes
- Tillåter `/auth/*` routes utan inloggning

**VIKTIGT:** Lägg INTE till en `middleware.ts` om `proxy.ts` finns — builden failar.

### Dockerfile med NEXT_PUBLIC_ vars
Next.js bäddar in `NEXT_PUBLIC_*` vid build-time. I Docker måste de skickas som build args:

```dockerfile
ARG NEXT_PUBLIC_SUPABASE_URL
ARG NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
ENV NEXT_PUBLIC_SUPABASE_URL=$NEXT_PUBLIC_SUPABASE_URL
ENV NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=$NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
RUN npm run build
```

Railway skickar automatiskt env-vars som matchar `ARG`-namn till Docker-bygget.

## Gotchas

1. **`NEXT_PUBLIC_*` måste finnas vid build-time.** Sätts de bara som runtime env-vars ser klienten dem inte. Använd Docker `ARG` + `ENV`.

2. **service_role-nyckeln ger full access.** Använd aldrig i klient-kod. Bara i server-side routes och API:er.

3. **Email-verifiering är på som standard.** Stäng av med `mailer_autoconfirm: true` för test. Slå på igen i produktion.

4. **Supabase Management API vs Project API.** Management API (`api.supabase.com`) hanterar projekt-config (auth settings, etc.) med `sbp_` token. Project API (`<ref>.supabase.co`) hanterar data och auth med anon/service_role keys.

5. **Google OAuth redirect URI.** Måste matcha exakt: `https://<ref>.supabase.co/auth/v1/callback`. Inte din apps URL.

## Testresultat

| Operation | Resultat |
|-----------|----------|
| Email signup | OK — användare skapad i Supabase |
| Email login | OK — redirect till skyddad dashboard |
| Session refresh | OK — proxy.ts hanterar automatiskt |
| Route protection | OK — /dashboard kräver inloggning |
| Admin API (lista användare) | OK — 2 användare verifierade |
| Auth config API | OK — alla providers listade/patchade |
