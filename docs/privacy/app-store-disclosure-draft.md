# App Store privacy disclosure — v2 candidate

Prepared and saved in App Store Connect on 20 September 2026. Protocol 2 and
the bilingual policy are live; legacy financial records have been scrubbed.
All three categories below are configured for App Functionality, linked to
the user, with tracking disabled. The live policy URL is saved. Final Publish
awaits the user's explicit confirmation of Apple's accuracy/compliance
attestation; no claim is made that the label is published yet. The iOS privacy
manifest does not submit the questionnaire automatically.

Policy URL after deployment: https://getclockin.netlify.app/privacy/
Privacy choices: Settings → Privacy & Live Activity in the app. Do not invent
a separate web deletion endpoint; records cannot be found by a person's name.

| Data | Candidate category | Purpose | Linked / tracking |
| --- | --- | --- | --- |
| Temporary per-activity push routing token | Identifiers → Device ID | App Functionality | Linked: yes (conservative routing identifier); tracking: no |
| Registration/expiry timing and use of the optional update feature | Usage Data → Other Usage Data | App Functionality | Linked: yes; tracking: no |
| Provider connection/security data, including IP where retained | Diagnostics → Other Diagnostic Data | App Functionality/security | Linked: yes (conservative); tracking: no |

Verify the last category against Netlify's actual retained provider data and its
purpose. Apple says IP addresses should be categorized by use; do not claim
anonymity merely because Clockin has no account system. Provider analytics,
location derivation or other uses would require revisiting these categories.

For **v2 only**, hourly rate, earnings, notes, currency/exchange rate, theme and
session start do not reach the relay. Financial Info and User Content should
not be selected for data that stays on device. **Protocol 1 does send financial
values and notes**: do not use the v2 answers while v1 collection still runs.
Review the separate Frankfurter rate-date requests and optional Radio Paradise
streams before final submission. Do not apply an optional-collection exemption
without satisfying all of Apple's stated conditions.

Sources reviewed:
- https://developer.apple.com/app-store/app-privacy-details/
- https://developer.apple.com/app-store/review/guidelines/#privacy
- https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests

The user supplied the public policy identity/contact in owner.json. Applicable
legal bases, provider processing arrangements and international-transfer
requirements remain matters for the controller to confirm. This
draft is a technical data-flow mapping, not a legal compliance determination.
