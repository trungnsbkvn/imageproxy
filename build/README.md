# imageproxy — Windows deploy bundle

Copy this folder to the server (e.g. `C:\svc\imageproxy\`) and follow the checklist.
`imageproxy.exe` itself is **not** committed to git (built artifact) — produce it with
`..\build.ps1`. Full reference: [../DEPLOY.md](../DEPLOY.md).

## Contents
| File | Purpose |
|------|---------|
| `imageproxy.exe` | the resizer binary (built by `..\build.ps1`; not in git) |
| `install-service.ps1` | install as a **native** Windows service (**no nssm**; edit CONFIG first) |
| `uninstall-service.ps1` | stop + remove the service |
| `run.ps1` | run in the foreground for testing |
| `config.example.env` | env-var alternative to CLI flags |

> **No nssm required.** The binary registers itself with the Windows Service Control
> Manager via `imageproxy.exe -service install`, so it's a real service in `services.msc`
> with no third-party wrapper.

## Deploy checklist (Windows)
1. **Build** the exe (on a machine with Go): from the repo root run `.\build.ps1`
   → produces `build\imageproxy.exe`.
2. **Copy** this `build\` folder to the server, e.g. `C:\svc\imageproxy\`.
3. **Edit** `install-service.ps1` → the CONFIG block (cache dir, allowHosts, port, optional key).
4. **Install** (elevated PowerShell):
   `powershell -ExecutionPolicy Bypass -File .\install-service.ps1`
   → registers + starts the service, sets auto-start + crash-restart via `sc.exe`.
5. **Smoke test:** `curl.exe http://127.0.0.1:8080/health-check` → `OK`  (logs: `imageproxy.log`)
6. **IIS:** add the reverse-proxy rule (needs URL Rewrite + ARR, proxy enabled):
   ```xml
   <rule name="ImageProxy" stopProcessing="true">
     <match url="^img/(.*)" />
     <action type="Rewrite" url="http://localhost:8080/{R:1}" />
   </rule>
   ```
7. **Build env:** set `IMAGE_RESIZER=imageproxy` so the site emits `/img/...` URLs.
8. **Verify live:** `curl.exe -I "https://luatsumienbac.vn/img/800x,avif,q55/<b64url-of-a-/media-file>"`
   → `200`, `Content-Type: image/avif`.

Linux deployment (systemd + nginx/Caddy) is in [../DEPLOY.md](../DEPLOY.md).
