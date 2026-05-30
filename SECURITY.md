# Beveiliging — QA Dashboard

Dit document beschrijft de belangrijkste beveiligingsmaatregelen van de
applicatie en de bewuste afwegingen die daarbij gemaakt zijn.

## Authenticatie & sessies

- **Wachtwoorden** worden gehasht met bcrypt (cost 12). Er geldt een
  wachtwoordbeleid (min. 10 tekens, hoofdletter, kleine letter, cijfer en
  speciaal teken); zie `backend/src/common/password-policy.ts` en de
  gespiegelde frontend-validatie in `frontend/lib/utils/password_policy.dart`.
- **Bootstrap-admin** wordt niet in de broncode bewaard maar via de
  environment-variabelen `BOOTSTRAP_ADMIN_EMAIL` / `BOOTSTRAP_ADMIN_PASSWORD`
  (zie `backend/.env.example`). De app weigert te starten zonder geldige,
  beleidsconforme waarden.
- **JWT**: access-token (15 min) + refresh-token (7 dagen) met HS256. Secrets
  uit environment-variabelen; de app weigert te starten bij ontbrekende of
  zwakke secrets (`backend/src/auth/jwt.config.ts`).
- **Refresh-token-rotatie**: bij elke refresh wordt de oude sessie ingetrokken
  en een nieuwe uitgegeven; sessies zijn server-side intrekbaar.

## Toegangscontrole

- Globale `JwtAuthGuard`: alle endpoints zijn standaard beschermd, tenzij
  expliciet `@Public()`.
- `AdminGuard` en per-module checks (bv. `ovaAccess`) dwingen rechten
  server-side af.
- `PATCH /users/:id` whitelistet bewust alleen profielvelden; rechten
  (`isAdmin`, module-toegang) lopen uitsluitend via accountbeheer om
  privilege-escalation te voorkomen.

## Input & misbruik

- Globale `ValidationPipe` met `whitelist`: onbekende velden worden uit
  request-bodies gestript (bescherming tegen mass-assignment).
- **Rate-limiting** op de auth-endpoints (`@nestjs/throttler`): login en
  forgot-password 5/min, reset 10/min, verify 20/min, per client-IP.
- **Anti-enumeratie**: forgot-password geeft altijd dezelfde generieke melding,
  ongeacht of het e-mailadres bestaat.
- **Upload-limieten** op de JAP/GPP-import: max 10 MB, 1 bestand, alleen
  `.xlsx/.xls/.csv`.

## Bekende afweging: opslag van tokens in de frontend

De Flutter-frontend bewaart het access- en refresh-token in
`SharedPreferences` (op web = `localStorage`). Dat is toegankelijk vanuit
JavaScript en dus kwetsbaar wanneer er een XSS-lek zou zijn.

Dit is een **bewuste, geaccepteerde afweging** — het is het gangbare patroon
voor single-page applications. Het risico wordt beperkt door:

- een korte access-token-levensduur (15 min);
- refresh-token-rotatie met server-side intrekken van sessies.

### Sterkere alternatief (toekomstige verbetering)

De refresh-token in een **httpOnly + Secure + SameSite=Strict cookie** zetten,
zodat JavaScript er niet bij kan. Dit is technisch haalbaar omdat de frontend
en de API op dezelfde host draaien (`tst.vlotterqa.tech`). Het vereist wel:

- backend: `login` / `refresh` / `logout` die de cookie zetten, lezen en
  wissen (met `cookie-parser`);
- frontend: de sessie-herstel-flow herschrijven en requests met
  `withCredentials` versturen;
- aandacht voor lokale dev (Secure-cookies werken niet over `http://localhost`).

Deze migratie is bewust uitgesteld omdat ze de volledige auth-flow raakt en
grondig getest moet worden; ze is niet nodig voor de huidige oplevering.
