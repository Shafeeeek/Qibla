# Qibla / قبلتي

An Arabic, right-to-left React website adapted from the existing Qibla SwiftUI app. The original iOS project is retained in `QiblaApp/`.

## Run the website

Requires Node.js 22.12+ (Node 24 recommended).

```sh
npm install
npm run dev
```

Open http://localhost:5173. The website starts with **Cairo, Egypt**, visibly selected in the location control. Select another city or request your current location. Geolocation and the phone compass require HTTPS in production (localhost works during development).

## Included

- Responsive Arabic RTL layout with the app's emerald-and-gold palette, bundled Arabic fonts, and keyboard-accessible controls.
- Prayer times calculated locally with [Adhan JS](https://github.com/batoulapps/adhan-js), four calculation methods, and two Asr conventions.
- Next-prayer countdown, tomorrow's Fajr after Isha, and date navigation. Sunrise is displayed separately and is not treated as a prayer.
- City-aware time zones and daylight-saving handling. With GPS outside the listed cities, the initial zone comes from the device; it can be corrected in Settings.
- Qibla bearing and distance to Mecca; live compass on devices that expose an absolute heading. A labeled north-relative diagram remains available on desktop.
- Prayer, morning/evening azkar, and Quran-page tracking; completion streaks, weekly chart, and 30-day activity history.
- Create, update, complete, and delete local halaqa goals.
- Chat UI integrated with the existing `/api/chat` backend, with suggestions, saved conversation, loading, retry, and error states.
- Optional browser reminders while the page is open and active. Browsers may throttle background tabs; this is not a background push or native notification service.

Location, settings, worship logs, halaqas, and conversation history are stored in this browser's local storage. Halaqas are local goals; there is no account system, cross-device synchronization, or multiplayer sharing. Native iOS AR and widgets remain specific to the iOS app.

## Optional AI assistant

The core website works independently of the backend. To enable AI replies, configure a server-side Gemini key in `QiblaBackend/.env` using `QiblaBackend/.env.example`, then run in a second terminal:

```sh
cd QiblaBackend
npm install
npm start
```

The development server proxies `/api` to `http://127.0.0.1:3000`. Change `QIBLA_BACKEND_URL` in a root `.env` if necessary. The Gemini model is configurable using `GEMINI_MODEL`; its default is `gemini-3.5-flash-lite` from the [Gemini model catalog](https://ai.google.dev/gemini-api/docs/models).

Keep API keys only on the server. An old embedded fallback key was removed from the backend; revoke it in its provider console if it is still active. Never put secrets in a `VITE_` variable. For public assistant access, configure the backend's allowed origin and hosting-side access/rate controls.

## Build and verify

```sh
npm test
npm run test:e2e
npm run build
npm run preview
```

`npm run build` creates `dist/`, ready for static hosting. Navigation uses URL hashes, so static hosting does not need route rewrites. For AI in production, route `/api/chat` to the backend, or set `VITE_API_BASE_URL` to your HTTPS backend URL **before building**. The Vite development proxy does not run in the static production build.

Browser tests use Playwright. Install Chromium with `npx playwright install chromium`, or set `PLAYWRIGHT_EXECUTABLE_PATH` to a locally installed Chromium/Chrome executable. Tests exercise desktop/mobile layout, tracking persistence, location selection, halaqas, and assistant success/failure with mocked API responses; they do not consume Gemini credits.

## Deploy to Vercel

Deploy from this repository's root using the free Hobby plan for personal,
noncommercial use. Use `myqiblaty` as the project name if available. Vercel assigns
a free `*.vercel.app` address; a custom `.com` domain requires separate registration.

`vercel.json` configures the Vite build and installs the assistant's backend
dependencies. The `api/` entry points serve `/api/chat` and `/api/health` as Vercel
Functions. No separate backend host is required.

```sh
npx vercel login
npx vercel
# After reviewing the preview:
npx vercel --prod
```

To enable hosted AI replies, set `GEMINI_API_KEY` in Vercel's server-side environment
variables and redeploy. `GEMINI_MODEL` is optional. Gemini's quota and billing are
separate from Vercel hosting. Without a key, the core website still works and the
assistant reports that it is not configured. `.vercelignore` excludes local
environment files and the native iOS project from deployment uploads.

## Project structure

- `QiblaWeb/src/App.jsx`: app shell, prayer dashboard, location selection, reminders.
- `QiblaWeb/src/pages.jsx`: compass, worship, halaqas, assistant, settings.
- `QiblaWeb/src/lib.js`: prayer/time-zone, Qibla, and tracking calculations.
- `QiblaWeb/src/components.jsx`: shared UI and SVG illustrations.
- `QiblaWeb/src/styles.css`: responsive design.
- `QiblaBackend/`: existing Express/Gemini assistant service.
- `QiblaApp/`, `QiblaWidget/`: original native app and widget.

## Run the iOS app

Open `Qibla.xcodeproj` in Xcode, select an iPhone simulator, and press **Run**.
