# Clockin Live Activity earnings

> Protocol 2 is live as of 20 September 2026, deployment
> `6aaf2fdca66ab66fd2ad1487`. Legacy financial content was scrubbed.
> iOS 0.2 (11) uploaded; see `../../docs/ios-live-activity-build-11.md`
> for distribution status and the coordinated migration.

Sends earnings updates to the iPhone Live Activity every minute while
Clockin is suspended; APNs delivery timing can vary. The existing system-rendered elapsed-time label is
unchanged. iPhone Live Activity mirroring can carry these updates to macOS;
this service does not synchronize native Mac work records.

## Previous protocol-1 rollout (historical)

- Apple team `LU36PKDPT3`, app `com.erdmncdr.clockin`: Push Notifications enabled.
- Production APNs key `FQ9GR4927V` (`Clockin Live Activity`) created on
  2026-09-20 with explicit user approval, restricted to `com.erdmncdr.clockin`.
  The user downloaded `AuthKey_<KEY_ID>.p8` to Downloads. Its EC P-256
  signature was validated without printing its contents; it is configured in
  the existing Netlify site's production environment. Do not put a `.p8` in
  the repository or embed it in an app/function bundle.
- Earlier keys `F2463RSX8J` and `76AJMHFSTF` were both revoked with explicit
  final user confirmation. Their downloads had stopped without saving files.
- Service deployed to `https://getclockin.netlify.app` on 2026-09-20 (Istanbul),
  latest deploy `6aaf2579b0540a7cbc3c18d3`, context `production`. All 223 published
  website file hashes were preserved. Health returns 200 with `pushConfigured: true`;
  unauthenticated PUT/DELETE return 401 and unsupported PATCH returns 405.
  The production API confirms the minute schedule and 30/minute rate limit.
  A synthetic registration reaches APNs and returns the expected 422 for an
  invalid device token; a direct APNs probe returns 400 `BadDeviceToken`.
  These checks do not prove delivery to a real Live Activity.
- The user subsequently authorized installation on the existing Netlify
  project. The client endpoint now points to the verified production service.
  A signed release-testing app/widget `0.2 (9)` is prepared at
  `/tmp/clockin-live-activity-release-0.2-9/`, using HEAD plus only the five
  Live Activity client files. The profile includes the paired iPhone and
  `aps-environment: production`. The user chose TestFlight installation instead
  of direct device installation. Upload succeeded at 02:42 Istanbul time on
  2026-09-20; build `81ae4887-784c-4110-846f-964d6ec33af2` was subsequently
  verified Testing in both Clockin Internal and Clockin Public Beta.
  **Build 9 used an outdated UI source**; see
  `../../docs/ios-live-activity-build-10.md` for the corrective release and
  explicit source preparation. Do not repeat the HEAD-only release process.
  Corrective build **0.2 (10)** was uploaded at 03:03 Istanbul time and verified
  Testing in both existing groups; its 30 iOS check groups passed.
  A real production activity subsequently registered and the scheduler ran.
  The user confirmed 2–3 updates without opening the app, followed by a stall.
  See `../../docs/ios-live-activity-delivery.md` for the investigation and
  server-side delivery-priority correction. Device cadence remains to be verified.

## Protocol 2 behavior

`PUT /api/v1/live-activity` accepts a per-activity APNs token in the Authorization
header and only `{protocol: 2, environment, expiresAt}` in its JSON body.
Extra fields, including financial values or session content, are rejected.
Clockin's default-off consent must be enabled before token creation/registration.
The user may withdraw it in Settings without disabling the local timer.

The server sends only a timestamp once a minute. The widget combines it with
local ActivityKit attributes to calculate earnings. Hourly rate, earnings,
start time, currency, conversion rate, theme and note never enter the relay.
Dates use the Swift 2001 epoch in content-state and Unix time in APS metadata.
APNs priority 10, expiration 0 and a collapse identifier request prompt delivery
of the latest tick. Apple still controls delivery and notification budgets.

Storage keys are SHA-256 hashes of the routing token. The raw token is required
for APNs delivery and remains in the temporary registration; this is not
end-to-end encryption or a claim of anonymity. No list/read API exists.
Requests are limited to 4 KiB and 30/minute per IP/domain.

Before storing the raw token, a short pending lease reserves its hash and APNs
validates it against Clockin's topic. Conditional writes prevent a registration
already in flight from restoring a token after DELETE. Failed validation keeps
only a short-lived token-free pending marker, removed on cleanup. Repeat valid
registration is idempotent and cannot extend the original eight-hour expiry.

Pause, rate/currency/note/theme changes and consent withdrawal replace the local
activity, so queued pushes cannot restore old content. DELETE replaces an
existing record with a token-free stop marker until expiry. Failed removal is
queued locally across launches; Settings shows pending cleanup. Expired records
are not sent and are deleted on the next successful scheduled cleanup.

The first v2 tick scrubs legacy v1 financial records without sending them.
Old clients cannot register with v2: distribute build 11 and explain the new
opt-in. Preview functions use the same site-wide Blobs store; never issue PUT,
DELETE or manual ticks to a preview for testing. Use the in-memory tests.

Application logs include aggregate counts and generic errors only. Provider
connection/security logs are separate and may retain IP addresses; do not
claim the eight-hour application-record limit covers all provider data.

## Deployment

The adapter targets Netlify project `getclockin`, site ID
`406e1766-2c8b-4b61-99a1-f4736b8c512a`.
Installation on this existing project was explicitly authorized.

Required site-level environment variables in **production context**:

- `CLOCKIN_APNS_TEAM_ID`: `LU36PKDPT3`
- `CLOCKIN_APNS_KEY_ID`: `FQ9GR4927V`
- `CLOCKIN_APNS_PRIVATE_KEY`: full downloaded PEM, configured directly in the site's environment

The current free account rejects granular Functions scopes. Its API also
rejects `is_secret: true` with the default all-scopes setting because it includes
post-processing. These values therefore use ordinary site-level environment
variables restricted to production context: authorized Netlify account/API
users can read them. They are not in source, artifacts, logs or client code.
No paid plan or billing setting was enabled.

The account includes 300 credits each month. A production deployment uses 15;
compute uses 10 per GB-hour. At 1 GB, 43,200 monthly ticks averaging 0.5–1 second
would use 60–120 compute credits, excluding requests, transfer, other projects
and deployments. This is a planning estimate, not measured active APNs usage.
Free-plan exhaustion pauses projects instead of charging overages.

The created key supports Production (App Store/TestFlight). Local development
APNs requires a separate Sandbox key before end-to-end development-device
testing; simulator builds intentionally do not register. Do not widen the
key's topic permissions to other apps.

Install dependencies from the lockfile, run `node --test test/*.test.mjs`, then
build with `netlify functions:build --src functions --functions /tmp/clockin-live-functions`
from this directory. `python3 scripts/deploy-live-activity.py` from the repo root
creates and checks a preview while preserving the exact published website hashes.
`python3 scripts/deploy-live-activity.py --promote` redeploys those verified
function hashes with `draft: false` and checks production health. Do not use
Netlify's restore-preview action: it keeps the `deploy-preview` context and
does not load production-only environment variables.

Future **website** changes must deploy both `website/dist` and this directory's
`functions` with Netlify CLI. The older static ZIP uploader now refuses to run
when deployed functions exist, preventing an accidental removal of the relay.
Do not activate the client endpoint without deploying and checking the relay.

Before release, regenerate the app provisioning profile for the push
entitlement. Distribution export changes `aps-environment` to `production`.
The app reads the embedded profile for development/ad-hoc routing; Store and
TestFlight installs use production. Build numbers must follow the current
App Store Connect release state; this change does not choose or publish a build.

## Verification

The ten v2 relay tests cover timestamp-only payloads, strict field validation,
expiry, APNs rejection, idempotency, deletion races, invalid-token cleanup,
transient errors, payload limits and legacy financial-record removal. The
13 Swift privacy checks cover local arithmetic, dates, data minimization and
consent defaults. Historical v1 verification follows: iOS simulator and unsigned
device builds are separate compilation checks, not evidence of delivery.
On 2026-09-20 the eight relay tests and the final unsigned iPhone Release build
passed (`/tmp/clockin-live-activity-device-final.log`).

Required live check after deployment and phone installation:

1. Clock in at a rate with a visible per-minute increase. Background Clockin
   and observe the expanded Dynamic Island or Lock Screen for three minutes.
2. Pause from the Live Activity; verify neither time nor earnings increases.
3. Resume and verify earnings increases from the paused value. Clock out and
   verify the activity disappears and the relay stops sending.
4. Repeat pause and clock-out while offline; reconnect and check that stale
   notifications cannot restore the previous activity.
5. Verify the mirrored activity on the Mac and the deployed scheduler's
   delivery counts. The compact earnings label rounds down to whole currency
   units, so small rates may not visibly change every minute in compact mode.

References: [ActivityKit push updates](https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications),
[LiveActivityIntent](https://developer.apple.com/documentation/appintents/liveactivityintent),
[Netlify scheduled functions](https://docs.netlify.com/build/functions/scheduled-functions/).
