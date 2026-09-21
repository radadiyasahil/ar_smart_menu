# Local development — auto-reload

You do **not** need to manually restart servers if you start them in **watch / dev mode** once.

## Quick start (Windows)

Open **one** of these:

```powershell
# All 3 apps in separate windows (recommended)
.\scripts\dev-all.ps1

# Or individually:
.\scripts\dev-backend.ps1   # API — auto-restarts on C# changes
.\scripts\dev-admin.ps1     # Admin — browser refreshes on save
.\scripts\dev-flutter.ps1   # Owner app — hot reload on Dart save
```

## From Cursor / VS Code

1. **Terminal → Run Task…**
2. Choose **Dev: Start All (auto-reload)**

Or run **Dev: Backend (watch)** only if you only changed the API.

## What auto-reloads?

| App | Command | On file change |
|-----|---------|----------------|
| **Backend API** | `dotnet watch run` | Rebuilds & restarts (~2–5 s) |
| **Admin panel** | `npm run dev` (Vite) | Instant HMR in browser |
| **Flutter owner** | `flutter run -d chrome` | Hot reload on save (or press `r`) |
| **WebAR** | `cd webar-experience && npm run dev` | Instant HMR |

## When you still need a manual restart

- Changed `appsettings.json`, `.env`, or connection strings → restart **backend**
- Added a NuGet package or EF migration → restart **backend**
- Changed `pubspec.yaml` → stop Flutter and run `flutter pub get` + restart
- Port already in use → stop the old process first

## Stop using plain `dotnet run`

Replace:

```powershell
dotnet run --launch-profile http
```

With:

```powershell
dotnet watch run --launch-profile http
```

Same port (`5232`), but restarts automatically when you save `.cs` files.
