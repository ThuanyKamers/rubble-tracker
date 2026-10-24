# Rubble Tracker

A mobile app (Android & iOS) that connects citizens and city workers to keep streets free of construction debris and discarded rubble. Built as a proposal for the city of **Palhoça (SC, Brazil)**.

> The app interface is in Brazilian Portuguese ("Cidade Limpa").

📄 **Full documentation** (English, Deutsch, Português): [Rubble Tracker on Notion](https://app.notion.com/p/4033f2d9e43b80ec8bb6cf9546658e61)

## How it works

**Citizens**
- Sign up with their CPF (Brazilian tax ID) and a password.
- Report rubble with **1 to 3 photos**, taken with the camera or chosen from the gallery, and an optional description such as *"in front of the dollar store"*.
- The report is pinned on the map at the **exact GPS position** where it was made.

**City workers**
- Have a separate login, created by the city (workers cannot self-register).
- See every open report on the map, or as a list sorted by distance.
- Mark rubble as **collected**, which removes it from the map for everyone.

## Precise duplicate detection

If several citizens report the same pile, the app must not create two records. But another pile just 10 m further down the street must still be reported. Each new report is compared with the open reports around it:

| Distance to the nearest open report | Result |
|---|---|
| up to 6 m | Same rubble: no new record; the citizen's photos and confirmation are added to the existing one |
| 6 m to 15 m | The app shows the nearby report (with photo) and asks the citizen whether it is the same pile |
| more than 15 m | New report |

To keep this reliable, the app only allows sending when the GPS accuracy is **±20 m or better**, and it blocks mocked (fake) locations. Reports are processed one at a time on the server, so two people reporting the same spot at the same second still produce a single record. All distances are configurable.

## Tech stack

| Layer | Technology |
|---|---|
| Mobile app | Flutter (Dart), `flutter_map` + OpenStreetMap, `geolocator`, `image_picker` |
| API | Node.js, Express, JWT authentication, `multer` for photo uploads |
| Database | PostgreSQL |
| Infrastructure | Docker Compose (optional) |

## Project structure

```
lib/
  screens/    login, sign-up, map, report form, worker list
  services/   API client, session storage, GPS
  models/     report and user models
  widgets/    report details, photo viewer
backend/
  src/        Express API, database migrations, auth, geo helpers
```

## Running locally

### 1. API

```bash
cp backend/.env.example backend/.env   # then edit the values
```

**With Docker**

```bash
docker compose up -d --build
docker compose exec api npm run criar-trabalhador -- <cpf> <password> "<full name>"
```

**Without Docker** (Node.js 22.9+ and PostgreSQL 16)

```sql
CREATE USER rubble_tracker WITH PASSWORD '<same as backend/.env>';
CREATE DATABASE rubble_tracker OWNER rubble_tracker;
```

```bash
cd backend
npm install
npm run criar-trabalhador -- <cpf> <password> "<full name>"
npm start
```

Tables are created automatically on startup.

### 2. App

```bash
flutter pub get
flutter run                                                  # Android emulator (uses 10.0.2.2:3000)
flutter run --dart-define=API_URL=http://<your-pc-ip>:3000   # physical device on the same network
```

## API

| Method | Route | Who |
|---|---|---|
| `POST` | `/auth/cadastro` | citizen sign-up |
| `POST` | `/auth/login` | everyone |
| `GET` | `/denuncias?minLat&maxLat&minLng&maxLng` | logged in |
| `POST` | `/denuncias` (multipart, 1–3 photos) | citizen |
| `POST` | `/denuncias/:id/confirmar` | citizen |
| `PATCH` | `/denuncias/:id/recolher` | worker |

## Before going to production

- Serve the API over HTTPS and remove `android:usesCleartextTraffic="true"`.
- Use a tile provider suited for production traffic (the free OpenStreetMap tile servers do not allow heavy usage).
- Set the official application ID / bundle ID.
- Store photos in object storage (e.g. S3) instead of the local disk.

## Author

Developed by [Thuany Kamers](https://github.com/ThuanyKamers).
