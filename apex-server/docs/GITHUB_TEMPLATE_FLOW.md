# GitHub Template Flow

Apex strategi for att bygga projekt snabbt: sök GitHub efter bästa template, klona, anpassa, bygga, deploya — allt i en Daytona-sandbox.

## Varför

Lovable och Replit använder egna komponentbibliotek. Apex har hela GitHub. Istället för att bygga 50+ komponenter från scratch kan vi klona ett repo med 11K stars som redan är testat av tusentals utvecklare.

## När ska vi använda templates vs bygga från scratch?

### Template (klona + anpassa)
- Projektet behöver komplex UI-infrastruktur (dashboard, admin panel, e-commerce)
- Det finns ett välunderhållet repo (>1K stars)
- Projektet handlar om att *anpassa* snarare än att *uppfinna*
- Etablerade mönster: dashboards, landing pages, portfolios, blogs

### Från scratch
- Unik logik eller interaktivitet som inget template löser
- Enkelt nog (en HTML-sida, ett API, ett script)
- Befintliga templates har onödiga dependencies som kostar mer att ta bort

### Beslutslogik (för AI-agenten)
```
1. Användaren beskriver sitt projekt
2. AI söker GitHub API efter bästa matchning
3. Om bra match (>70% feature overlap) → klona + anpassa
4. Om dålig match → bygg från scratch
5. Oavsett → patcha, customiza, deploya i Daytona
```

## Pipeline — Testad och Verifierad

### Steg 1: Sök GitHub
```python
# GitHub API search
import requests
r = requests.get("https://api.github.com/search/repositories", params={
    "q": "dashboard shadcn react",
    "sort": "stars",
    "per_page": 5
})
repos = r.json()["items"]
# Välj repo baserat på: stars, senast uppdaterad, dependencies, licens
```

**Urvalskriterier:**
- Stars: >500 = bra, >1K = mycket bra
- Senaste commit: <3 månader
- Licens: MIT/Apache/ISC (undvik GPL för kommersiellt)
- Dependencies: undvik auth-providers (Clerk, Auth0) om inte behövt
- README: Bra docs = enklare att anpassa

### Steg 2: Skapa sandbox + klona
```python
from daytona import Daytona, DaytonaConfig, CreateSandboxFromImageParams

d = Daytona(DaytonaConfig(api_key="dtn_...", target="us"))
sb = d.create(CreateSandboxFromImageParams(
    image="node:20-slim",    # eller python:3.12-slim-bookworm
    name=f"apex-{project_name}",
    env_vars={"NODE_ENV": "production"},
))

# Klona repo
sb.process.exec("apt-get update -qq && apt-get install -y -qq git", timeout=180)
sb.process.exec("git clone https://github.com/user/repo.git /workspace/app", timeout=120)
```

### Steg 3: Installera dependencies
```python
# VIKTIGT: pnpm OOM:ar i 1GB sandbox — använd npm
sb.process.exec(
    "cd /workspace/app && npm install --legacy-peer-deps --no-optional --ignore-scripts",
    timeout=300
)
# Om saknad dependency dyker upp vid build:
sb.process.exec("cd /workspace/app && npm install react-is --legacy-peer-deps")
```

### Steg 4: Patcha branding
```python
# sed fungerar bra för textersättning
sb.process.exec('sed -i "s/OriginalName/Apex/g" /workspace/app/src/config.ts')
sb.process.exec('sed -i "s/Original Description/Apex Project Dashboard/g" /workspace/app/src/config.ts')

# upload_file för helt nya filer (t.ex. logo)
sb.fs.upload_file("/tmp/local-logo.tsx", "/workspace/app/src/assets/logo.tsx")
```

### Steg 5: Bygga
```python
# Frigör minne först — döda gamla processer
sb.process.exec("""
for p in /proc/[0-9]*/cmdline; do
    pid=$(dirname $p | xargs basename)
    cmd=$(cat $p 2>/dev/null | tr '\\0' ' ')
    case $cmd in *node*) kill -9 $pid 2>/dev/null;; esac
done
""")

# Bygg med minnesoptimering
r = sb.process.exec(
    "cd /workspace/app && NODE_OPTIONS='--max-old-space-size=768' npx vite build 2>&1",
    timeout=300
)
```

### Steg 6: Serva
```python
# Custom Node.js server — serve-paketet är opålitligt med portar
server_js = '''
const http = require("http");
const fs = require("fs");
const path = require("path");
const PORT = 3000;
const DIR = "/workspace/app/dist";
const MIME = {".html":"text/html",".js":"application/javascript",".css":"text/css",".json":"application/json",".png":"image/png",".svg":"image/svg+xml",".ico":"image/x-icon",".woff2":"font/woff2",".woff":"font/woff",".ttf":"font/ttf",".webp":"image/webp"};
http.createServer((req, res) => {
  const url = req.url.split("?")[0];
  let filePath = path.join(DIR, url === "/" ? "index.html" : url);
  const ext = path.extname(filePath);
  if (!ext) filePath = path.join(DIR, "index.html");
  fs.readFile(filePath, (err, data) => {
    if (err) { fs.readFile(path.join(DIR, "index.html"), (e2, d2) => { res.writeHead(200, {"Content-Type":"text/html"}); res.end(d2); }); return; }
    res.writeHead(200, {"Content-Type": MIME[ext] || "application/octet-stream"});
    res.end(data);
  });
}).listen(PORT, () => console.log("Server on " + PORT));
'''
# Skriv via heredoc i sandbox
sb.process.exec("cat > /workspace/server.js << 'EOF'\n" + server_js + "\nEOF")
sb.process.exec("nohup node /workspace/server.js > /tmp/server.log 2>&1 &")

# Hämta preview URL
url = sb.get_preview_link(3000)
print(url.url)  # https://3000-{id}.proxy.daytona.works
```

## Testresultat (2025-01-30)

| Steg | Tid | Resultat |
|------|-----|----------|
| Skapa sandbox (node:20-slim) | ~10s | OK |
| git clone (420-star repo) | ~5s | OK |
| npm install | ~45s | OK (pnpm OOM:ade) |
| Patcha branding (15 sed-kommandon) | <2s | OK |
| Vite build | ~27s | OK (med 768MB heap) |
| Starta server | <1s | OK |
| **Totalt** | **~90s** | **Full dashboard live** |

## Repos som testats

| Repo | Stars | Stack | Resultat |
|------|-------|-------|----------|
| satnaing/shadcn-admin | 11K | Vite + React + shadcn | Fungerade — men har Clerk auth dependency |
| silicondeck/shadcn-dashboard-landing-template | 420 | Vite + React + shadcn | Fungerade perfekt — ingen auth |
| Barty-Bart/nextjs-supabase-shadcn-boilerplate | 46 | Next.js 16 + Supabase + shadcn | Fungerade perfekt — fullstack med auth |

## Vad som patchades (dashboard-test)

- Sidebar: "Shadcn Admin" → "Apex", "Vite + ShadcnUI" → "Project Dashboard"
- Overview cards: Total Revenue → Active Projects, Subscriptions → Sandboxes Running, Sales → Files Generated, Active Now → Deploy Success
- Recent Sales → Recent Deployments
- Logo: shadcn-knot SVG → Apex triangel SVG
- Användarinfo: satnaing → apex-user
- HTML title: "Shadcn Admin" → "Apex"

## Vad som patchades (fullstack-test)

- `login-form.tsx` — Google OAuth-knapp + `signInWithOAuth` handler
- `sign-up-form.tsx` — Google OAuth-knapp överst + separator
- `app/auth/callback/route.ts` — **ny fil** — OAuth redirect handler (`exchangeCodeForSession`)
- `app/page.tsx` — fixade TypeScript-fel (async server component)
- `next.config.ts` — `output: "standalone"` för Docker deploy
- `Dockerfile` — **ny fil** — multi-stage build med build args

---

## Fullstack Deploy Pipeline (GitHub → Supabase → Railway)

### Översikt

```
GitHub Template → Lokal patch → Railway Docker Build → Produktion
                                      ↕
                                  Supabase
                              (Auth + Database)
```

### Steg 1: Sök GitHub
```python
# Sök efter fullstack-template med auth
r = requests.get("https://api.github.com/search/repositories", params={
    "q": "nextjs supabase auth starter template",
    "sort": "stars",
    "per_page": 10
})
```

### Steg 2: Klona lokalt
```bash
git clone https://github.com/user/repo.git /tmp/project
```

### Steg 3: Supabase-setup
```bash
# Hämta API-nycklar
supabase projects api-keys --project-ref <ref-id>

# Stäng av email-verifiering (för test)
curl -X PATCH \
  -H "Authorization: Bearer sbp_..." \
  -d '{"mailer_autoconfirm": true}' \
  "https://api.supabase.com/v1/projects/<ref>/config/auth"

# Aktivera Google OAuth (när credentials finns)
curl -X PATCH \
  -H "Authorization: Bearer sbp_..." \
  -d '{
    "external_google_enabled": true,
    "external_google_client_id": "...",
    "external_google_secret": "..."
  }' \
  "https://api.supabase.com/v1/projects/<ref>/config/auth"
```

### Steg 4: Patcha filer + Dockerfile
```bash
# Patcha auth-komponenter, lägg till OAuth
# Skapa Dockerfile med build args för NEXT_PUBLIC_ vars
```

**Dockerfile-mönster för Next.js + Supabase:**
```dockerfile
FROM node:20-slim AS base

FROM base AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --legacy-peer-deps

FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
ARG NEXT_PUBLIC_SUPABASE_URL
ARG NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
ENV NEXT_PUBLIC_SUPABASE_URL=$NEXT_PUBLIC_SUPABASE_URL
ENV NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=$NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY
RUN npm run build

FROM base AS runner
WORKDIR /app
ENV NODE_ENV=production
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs
RUN mkdir -p ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
USER nextjs
EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"
CMD ["node", "server.js"]
```

### Steg 5: Railway deploy
```bash
# Init + link
railway init --name my-project

# Sätt env-vars (VIKTIGT: innan deploy så Docker build args fungerar)
railway variables \
  --set "NEXT_PUBLIC_SUPABASE_URL=https://xxx.supabase.co" \
  --set "NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=eyJ..." \
  --set "PORT=3000" \
  --skip-deploys

# Deploy
railway up --detach

# Generera publik URL
railway domain
```

### Steg 6: Verifiera
```bash
# Kolla status
railway service status --all

# Se build-loggar vid fel
railway logs --build

# Kolla Supabase-användare
curl -H "apikey: <service_role_key>" \
  -H "Authorization: Bearer <service_role_key>" \
  "https://xxx.supabase.co/auth/v1/admin/users"
```

### Testresultat (2026-01-30)

| Steg | Resultat |
|------|----------|
| GitHub clone | OK — Next.js 16 + Supabase + shadcn |
| Supabase projekt (Ireland) | OK — `jmrutiohfsordxphqdxe` |
| Patcha 5 filer | OK — Google OAuth, callback, Dockerfile |
| Railway deploy | OK — 4 försök (se gotchas nedan) |
| Email signup | OK — 2 användare skapade |
| Email login | OK — Redirect till skyddad dashboard |
| Dashboard | OK — "Welcome, demo@apex.dev" |
| Google-knapp | OK — Renderas, behöver Google Cloud credentials |

Live: `https://apex-fullstack-test-production.up.railway.app`

---

## Gotchas

1. **pnpm OOM:ar i 1GB cgroup.** Använd `npm install --legacy-peer-deps --no-optional --ignore-scripts` istället.

2. **`serve` npm-paketet binder inte till angiven port.** `-l 8000`, `-p 8000`, `--listen 8000` ignoreras alla. Använd custom Node.js server istället.

3. **Döda zombie-processer före build.** Gamla serve/node-processer äter minne. Sandbox har ingen `ps`, `killall`, `pkill` — iterera över `/proc/[0-9]*/cmdline` och kill manuellt.

4. **node:20-slim saknar systemverktyg.** Ingen `ps`, `fuser`, `ss`, `pgrep`, `curl`, `python3`. Bara `node`, `npm`, `bash`, `sed`, `grep`, `kill`.

5. **Cgroup-minnesgräns = 1GB.** Vite build kräver ~700MB. Sätt `NODE_OPTIONS='--max-old-space-size=768'` för att undvika OOM.

6. **upload_file tar lokal sökväg.** `sb.fs.upload_file(local_path, remote_path)` — inte innehåll direkt. Skriv till temp-fil först.

7. **Upload-gräns ~5MB.** Stora filer (tar.gz av build-artefakter) returnerar 400 Bad Request. Bygg inne i sandboxen istället.

8. **SPA-routing.** React-appar med client-side routing behöver server-side fallback (alla routes → index.html).

9. **Next.js 16 `proxy.ts` ersätter `middleware.ts`.** Om repot har en `proxy.ts`, lägg INTE till `middleware.ts` — builden failar med "Both middleware and proxy detected". Använd `proxy.ts` istället.

10. **`NEXT_PUBLIC_*` env-vars måste finnas vid build-time.** I Docker: använd `ARG` + `ENV` i builder-steget. Railway skickar automatiskt env-vars som Docker build args om de matchar `ARG`-namn.

11. **Dockerfile `COPY --from=builder /app/public` failar om mappen inte finns.** Lägg till `RUN mkdir -p ./public` som fallback.

12. **TypeScript-fel i templates.** Async server components som returnerar `void` (via `redirect()`) fungerar inte som JSX-children i Next.js 16. Gör hela `export default` till async istället.

13. **Railway `railway variables --set` (inte `set`).** Syntaxen är `railway variables --set "KEY=VALUE"`, inte `railway variables set KEY=VALUE`.

14. **Supabase auth-config via API.** `mailer_autoconfirm: true` stänger av email-verifiering. Google OAuth kräver `external_google_enabled`, `external_google_client_id`, `external_google_secret`.

15. **Daytona sandbox ≠ production build.** Next.js-byggen OOM:ar i 1GB sandbox. Bygg via Railway/Fly.io Docker builder istället (de har mer minne). Sandboxen är bra för development/preview men inte för produktion-builds av stora appar.
