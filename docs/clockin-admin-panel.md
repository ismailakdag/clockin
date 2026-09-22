# Clockin service panel

Entry point: `/admin/`. The page is Turkish and adapts to phone screens.
It displays aggregate Live Activity registrations, not unique people or app presence.

The scheduled push job writes one `monitor/latest` aggregate snapshot per minute.
No extra requests or tracking identifiers are added to the iOS client. The panel
reads this one object once per minute while visible; hidden tabs stop polling.
There is no historical timeline. Snapshots older than three minutes, incomplete
counts, missing data and errors are explicitly distinguished from current data.
APNs acceptance is not proof of delivery or rendering.

## Access

- `CLOCKIN_ADMIN_PASSWORD_HASH`: SHA-256 of a generated 192-bit random panel password.
  This construction is for a high-entropy generated credential, not a human-chosen password.
- `CLOCKIN_ADMIN_SESSION_SECRET`: independent random 256-bit HMAC key.
- Both settings belong only to getclockin's **production** environment. Netlify's
  free plan rejected Functions-only scoping, so the user explicitly approved the
  standard project scopes (including build and function runtime). They are not
  injected into browser code and have no deploy-preview values.
- Sessions expire after eight hours and use host-bound signed `__Host-` cookies
  with Secure, HttpOnly and SameSite=Strict. The browser stores no password or
  session token in localStorage or sessionStorage. Logout clears the cookie.
- Stateless sessions remain cryptographically valid until expiry; rotating the
  session key revokes all outstanding sessions when needed.
- Login/logout validate Origin; the endpoint enforces a 1 KiB request limit.
  The Netlify function declares 20 requests per minute per IP/domain. Responses
  are not cached. CSP blocks inline scripts, framing and third-party resources.
- No token, activity ID, earnings, notes or user identity is returned by the panel API.
- The panel keeps a rolling aggregate history in `monitor/history`: two hours at one
  minute and twenty four hours at five minutes, counts and timestamps only. One blob of
  about 20 KB is rewritten each minute and nothing older is retained. This is the
  "aggregate delivery counts" the published policy already allows in application logs;
  a partial round is left out so the series never shows a dip that did not happen.

## Validation

16 Node tests passed, including existing relay regressions and access control,
cookie tampering/expiry/host binding, input size, stale data, snapshot allowlisting
and aggregate scheduler counts. Netlify function bundles built successfully.
Local browser checks with synthetic data passed: rejected wrong password,
successful login, refresh, logout, and 390px mobile layout without horizontal overflow.

## Deployment state

The user approved production-only credential provisioning and then explicitly
approved the free plan's standard scope after Functions-only configuration returned
403. Credentials were provisioned successfully. Verified preview:
`6aafbb99563b510fb3213f1c`; production deployment:
`6aafbc33cea9641d26644896` at https://getclockin.netlify.app/admin/.
All 224 previously published site file hashes were preserved and production APNs
configuration remained available.

For subsequent releases, create a draft deployment with
`scripts/deploy-live-activity.py --admin --bundle /tmp/clockin-admin-functions
--privacy-page /tmp/clockin-privacy/index.html`, verify the draft, then promote the
same bundles with `--promote`. This preserves all published site file hashes.
Live verification passed: anonymous status returns 401, the generated password
creates a secure cookie, authenticated status returns only aggregate fields, and
logout clears the cookie. The next automatic scheduled heartbeat was fresh and
reported 4 active, 5 stopped, 0 pending, 4 APNs accepted, 0 failed, 0 remaining.
The deployed bundle declares a 20/minute IP/domain rule; saturation of the live
login endpoint was not load-tested to avoid interrupting the owner's login.

The generated login details are in a mode-0600 file under the mode-0700 directory
`/tmp/clockin-admin-credentials/Clockin-panel-giris.txt`, opened for the owner.
Save the password in a password manager; temporary local files are not durable storage.

References: [Netlify rate limits](https://docs.netlify.com/manage/security/secure-access-to-sites/rate-limiting/)
and [environment-variable API](https://docs.netlify.com/api-and-cli-guides/api-guides/get-started-with-api/).
