# Launch checklist: Ticklist (store name: Plandot)

Verified against official docs and web sources on **21 Nov 2026**. The official-docs checks were carried out for the sibling app's kit (`~/TEST/Habitgrid/launch/`) on the same day and apply unchanged here. Items marked **⚠ unverified** come from memory or from secondary sources only; re-check them in the console when you get there.

Fixed identifiers (already in the code, so don't change them):
- Android `applicationId` / iOS bundle ID: **`com.swalih60.ticklist`**. It is permanent after the first upload. The recommended store name is **Plandot** (NAME_CHECK.md); keep this ID anyway.
- RevenueCat entitlement **`pro`**, offering **`default`**, packages **`$rc_annual`**, **`$rc_monthly`**, **`$rc_lifetime`**
- Keys go in `lib/config.dart`: `AppConfig.revenueCatAppleKey` / `AppConfig.revenueCatGoogleKey` (currently `REPLACE_WITH_…`)
- Policy URLs already used by the app: `https://swalih60.github.io/Ticklist/privacy.html` and `/terms.html`

Suggested product IDs (use the same strings on both stores, which makes RevenueCat easier to read):

| Product | Apple product ID (type) | Google Play | RevenueCat package |
|---|---|---|---|
| Yearly + 7-day trial | `ticklist_pro_yearly` (auto-renewable) | Subscription `ticklist_pro`, base plan `yearly` (+ offer `trial7`) | `$rc_annual` |
| Monthly | `ticklist_pro_monthly` (auto-renewable) | Subscription `ticklist_pro`, base plan `monthly` | `$rc_monthly` |
| Lifetime | `ticklist_pro_lifetime` (non-consumable) | One-time product `ticklist_pro_lifetime` | `$rc_lifetime` |

Apple product IDs can **never be reused**, even after deletion, so type them carefully.

**Suggested order** (the Google 14-day test is the critical path, so start it first): 0 → D (pages live) → A1–A6 → start the closed test → B and C during the 14 days → A8 production.

---

## 0. Before anything

- [ ] Decide the final name (NAME_CHECK.md). The name in the store can change later; the bundle ID cannot.
- [ ] If renaming to Plandot, the Flutter developer updates `AppConfig.appName`, the "Ticklist Pro" strings in `paywall_screen.dart` / `settings_screen.dart`, and the display names (`CFBundleDisplayName` in `ios/Runner/Info.plist`, `android:label` in `AndroidManifest.xml`). Store name, in-app name and paywall must match, or App Review may flag it (guideline 2.3.8).
- [ ] Paywall copy says **"8 premium themes"**, but there are 8 accent themes of which 1 is free, so 7 are Pro. Change it to "7 premium themes" or "Premium themes" (store copy already avoids a number).
- [ ] Create a real support mailbox and replace every `support@EXAMPLE.com`: `docs/*.html`, `launch/STORE_LISTING.md`, and `AppConfig.supportEmail` in `lib/config.dart` (the Flutter developer's file).
- [ ] App icon 1024×1024 (iOS, no transparency) and 512×512 (Play). Play also needs a feature graphic 1024×500.
- [ ] Screenshots per STORE_LISTING.md §4. The iOS target is iPhone **and iPad** (`TARGETED_DEVICE_FAMILY = "1,2"`), so either make 13" iPad screenshots or have the Flutter developer set it to iPhone-only before the first upload.
- [ ] Store copy deliberately leaves out the v1.1 focus timer and timeline view. Don't ship visible entry points to unfinished features in v1.0 (App Review guideline 2.1 rejects incomplete features).

---

## A. Google Play Console

### A1. Developer account
- [ ] Go to <https://play.google.com/console/signup>. Choose **Personal** account ("Yourself"). An **Organization** account needs a D-U-N-S number (free, but can take up to about 30 days) and is **exempt** from the 12-tester rule below. ⚠ The exemption comes from secondary sources and was not checked on Google's own page.
- [ ] Pay the **one-time US$25** fee.
- [ ] Complete **identity verification** (government photo ID, legal name, address). Google says this may take a few days, and you can't publish until it is done. Verify the Android device too if asked (Play Console mobile app).
- [ ] Note: Play shows your **developer name** publicly. As an individual you can use a developer display name; your legal name is not shown. ⚠ For personal accounts **with monetisation**, Google shows your **address** publicly on the store listing. Use an address you're comfortable with. (This is current policy as far as I know, but it was not re-checked.)
- [ ] **Payments profile**: Play Console → Settings → Payments profile. Add bank account (INR payouts) and tax info. You can't create paid products until a merchant/payments profile exists.

### A2. Create the app
- [ ] Home → **Create app**: name "Plandot" (or your final name), default language English (United States) or English (India), App, Free, accept the declarations.
- [ ] **Free vs paid is permanent.** Choose **Free** (Pro is an in-app purchase).

### A3. App content (Policy → App content). Every item must be finished before review
- [ ] Privacy policy URL → `https://swalih60.github.io/Ticklist/privacy.html`
- [ ] App access → "All functionality is available without special access" (no login).
- [ ] Ads → **No, my app does not contain ads**.
- [ ] Content rating questionnaire (IARC) → category "All other app types"; answer **No** to everything. Expected result: Everyone / 3+.
- [ ] Target audience → **18+** (or 13+). Do **not** include under-13s, which would put the app under the Families policy.
- [ ] Data safety → see section E.
- [ ] Government apps → No. Financial features → "My app doesn't provide any financial features". Health apps → if asked, a task planner is **not** a health app. ⚠ The exact set of declarations Play asks for changes; answer whatever the page lists.
- [ ] Store listing → copy from STORE_LISTING.md §3; set category Productivity; contact email.

### A4. Build requirements (for the Flutter developer, listed here only as a gate)
- [ ] Upload an **Android App Bundle (.aab)** signed with your upload key and use **Play App Signing** (the default). Back up the upload keystore and its passwords. Losing them means a key reset request to Google.
- [ ] **Target API level:** new apps and updates must target **Android 16 / API 36** from **31 Aug 2026** (Google's target-SDK page). Check `targetSdk` in `android/app/build.gradle.kts`. The Flutter default depends on the Flutter version.
- [ ] Play Billing: `purchases_flutter` includes Google Play Billing Library and adds the `BILLING` permission automatically. Products can only be created **after** an AAB with billing has been uploaded to some track. So upload to **Internal testing** first. (⚠ There is no Android SDK on this Mac yet, per CLAUDE.md, so the first AAB build is a blocker for everything in A5–A6.)

### A5. Subscription and one-time products (Monetize with Play → Products)
- [ ] **Subscriptions → Create subscription**: Product ID `ticklist_pro`, name "Plandot Pro".
  - [ ] Base plan `yearly`: **auto-renewing**, billing period **1 year**, price USD 14.99 by default, then **set India manually to ₹699** (Edit prices → India). Grace period: default is fine. **Activate.**
  - [ ] Offer on `yearly`: ID `trial7`, eligibility **New customer acquisition → "Never had this subscription"**, phase **Free trial, 7 days**. **Activate.**
  - [ ] Base plan `monthly`: auto-renewing, 1 month, USD 2.99 / India ₹149. **Activate.**
- [ ] **One-time products** (earlier called "In-app products") → Create: Product ID `ticklist_pro_lifetime`, name "Plandot Pro Lifetime", USD 34.99 / India ₹1,499. **Activate.** (⚠ Google restructured one-time products in 2025 into product + purchase option. If you see "purchase options", create one "Buy" option with that price.)
- [ ] Settings → **License testing**: add your own Gmail and the testers' Gmail addresses. They can then buy with test cards and are not charged. Test subscriptions renew quickly (yearly ≈ every 30 min, monthly ≈ every 5 min). ⚠ Exact accelerated intervals not re-checked.

### A6. Closed testing: required for new personal accounts ✅ verified
Official rule (Play Console Help, answer 14151465): personal developer accounts **created after 13 Nov 2023** must run a **closed test with at least 12 testers who have been opted in continuously for at least 14 days** (the days must be consecutive) before they can apply for production access.
- [ ] Testing → **Closed testing** → create a track (e.g. "Alpha") → upload the AAB → countries: India + US (or all) → add testers as an **email list** or a **Google Group** (a Google Group is easier).
- [ ] Recruit **15–20 testers**, not exactly 12, because if anyone opts out the count drops below 12 and the 14-day window effectively restarts. Every tester must **open the opt-in link, accept, and install from Play** using the same Google account.
- [ ] Count 14 full days from when the 12th tester opted in. Ship 1–2 updates during the test and ask testers to actually use the app and leave feedback. The production application asks about tester engagement and what you changed, and thin answers are a common rejection reason (secondary sources).
- [ ] Use this window to test real purchases with license testers, the free trial, restore purchases, cancellation, the Pro gates (repeat picker, Insights, themes) and the one-time paywall after the first completed task.

### A7. Apply for production
- [ ] Dashboard → **Apply for production** → answer the three sections: *About your closed test*, *About your app*, *About your production readiness*. Google says reviews usually take **up to 7 days**. If rejected, you continue testing and apply again.

### A8. Production release
- [ ] Production → create release (promote the tested AAB), roll out to 20% → 100%. First-time review can take several days.

---

## B. App Store Connect (iOS)

### B1. Accounts and agreements
- [ ] Enrol in the **Apple Developer Program** as an **Individual** (US$99/year; in India Apple charges the local equivalent). The **seller name shown on the App Store will be your legal name** for individual accounts. That is unavoidable unless you enrol as an Organization, which needs a D-U-N-S number.
- [ ] App Store Connect → **Business** (earlier "Agreements, Tax, and Banking"): accept the **Paid Apps Agreement**, add the bank account and fill in the tax forms (for an Indian individual, the US tax form W-8BEN; India tax info as prompted). **IAPs will not load in the app (empty offerings) until the Paid Apps Agreement shows Active.**
- [ ] Apply for the **App Store Small Business Program** (15% commission instead of 30%, including on the lifetime IAP and first-year subscriptions; subscriptions are 15% after the first year anyway). It is not automatic.

### B2. Register the app
- [ ] developer.apple.com → Certificates, IDs & Profiles → Identifiers → App ID **`com.swalih60.ticklist`**, capability **In-App Purchase** (on by default). Push Notifications is **not** needed: reminders are local notifications.
- [ ] App Store Connect → Apps → **+ New App**: platform iOS, name (must be unique on the App Store; "TickList: To Do Daily Planner" already exists, see NAME_CHECK.md), primary language, bundle ID, SKU `ticklist-ios-001`.

### B3. Subscription group and products
- [ ] App → **Monetization → Subscriptions** → create a **Subscription Group** "Plandot Pro" (reference name). Add group localisation: display name "Plandot Pro".
- [ ] In the group, create **`ticklist_pro_yearly`**: duration 1 year, price US $14.99 base, then edit **India manually to the nearest point to ₹699**. Add localisation (display name "Plandot Pro Yearly", description "Repeating tasks, insights and themes"). Add a **review screenshot** of the paywall.
  - [ ] **Introductory offer**: Subscription Prices → Introductory Offers → all countries → **Free**, **1 week**.
- [ ] Create **`ticklist_pro_monthly`**: 1 month, US $2.99 / India ~₹149, localisation, screenshot.
- [ ] Subscription levels inside the group: put yearly and monthly at the **same level** (same features, so they count as crossgrades). ⚠ Either order works for RevenueCat.
- [ ] **Monetization → In-App Purchases → +** → **Non-Consumable** `ticklist_pro_lifetime`, US $34.99 / India ~₹1,499, localisation, screenshot.
- [ ] All products must show **"Ready to Submit"** and be **attached to the first app version** you submit (on the version page, "In-App Purchases and Subscriptions" section). The first IAPs can only be approved together with an app version.

### B4. App Store review requirements for subscriptions (guideline 3.1.2)
- [ ] The paywall shows the title, length and price of each plan, what the trial converts to, and links to **Privacy Policy** and **Terms of Use (EULA)**. It also has a **Restore Purchases** button.
- [ ] App description (STORE_LISTING.md) includes the Terms and Privacy links. Under App Information, leave **License Agreement = Apple Standard EULA**.
- [ ] Privacy Policy URL set in App Information; App Privacy filled in (section E).
- [ ] **Sandbox testing**: Users and Access → Sandbox → create a tester (a new email address), sign in on device under Settings → Developer (or App Store) → Sandbox Account. Then also test through **TestFlight**.
- [ ] Export compliance: the app uses only standard HTTPS, so answer "uses exempt encryption" (or set `ITSAppUsesNonExemptEncryption = NO` in Info.plist, which is the Flutter developer's job).
- [ ] Age rating questionnaire: all "None" → 4+.
- [ ] Review notes: "No login required. Pro can be tested with sandbox; free features need no purchase. Pro features: repeating tasks (task editor → Repeat), Insights (tab), themes (Settings). The paywall appears after the first task is completed, or from Settings → Upgrade."

---

## C. RevenueCat

- [ ] Sign up at <https://app.revenuecat.com>. Create a **Project** "Ticklist". (Free until $2.5k monthly tracked revenue. ⚠ Pricing not re-checked.)
- [ ] **Add the App Store app**: Project → Apps & providers → + App Store → bundle ID `com.swalih60.ticklist`.
  - [ ] Upload the **In-App Purchase Key** (required for StoreKit 2; the SDK v5+ uses StoreKit 2): App Store Connect → Users and Access → **Integrations → In-App Purchase** → generate a key → download `SubscriptionKey_XXXX.p8` (**downloadable only once**) → enter it in RevenueCat with its Key ID and the **Issuer ID shown on that same tab**. Do **not** upload the `AuthKey_…` App Store Connect API key here.
  - [ ] (Optional) App Store Connect API key (`AuthKey_….p8`) for automatic product import.
  - [ ] (Recommended) **App Store Server Notifications**: copy the URL RevenueCat shows and paste it into App Store Connect → App Information → App Store Server Notifications (Production and Sandbox, Version 2).
- [ ] **Add the Play Store app**: + Play Store → package `com.swalih60.ticklist`.
  - [ ] **Service account credentials JSON**: follow RevenueCat's "Google Play Service Credentials" guide (their Cloud Shell script creates `revenuecat-service-account` and `revenuecat-key.json`), invite that service account in Play Console → **Users and permissions** with the financial and order permissions the guide lists, then upload the JSON in RevenueCat. Credentials can take **up to ~36 hours** to become valid. RevenueCat validates three areas: subscriptions, inappproducts, monetization.
  - [ ] (Recommended) **Real-time developer notifications**: RevenueCat gives you a Pub/Sub topic → paste it into Play Console → Monetize with Play → Monetization setup → Real-time developer notifications.
- [ ] **Products**: Product catalog → Products → add (or import) all six products. On Google, subscriptions appear as `ticklist_pro:yearly` and `ticklist_pro:monthly` (product ID:base plan ID); the lifetime is `ticklist_pro_lifetime`.
- [ ] **Entitlement**: Product catalog → Entitlements → **+ New** → identifier **`pro`** (must match `AppConfig.entitlementId`) → attach **all six** products.
- [ ] **Offering**: Product catalog → Offerings → **+ New** → identifier **`default`** → add packages:
  - [ ] `$rc_annual` (choose "Annual" in the package dropdown) → `ticklist_pro_yearly` + `ticklist_pro:yearly`
  - [ ] `$rc_monthly` ("Monthly") → `ticklist_pro_monthly` + `ticklist_pro:monthly`
  - [ ] `$rc_lifetime` ("Lifetime") → `ticklist_pro_lifetime` (both stores)
  - [ ] Mark **`default`** as the **Default offering** (the app reads `offerings.current`).
- [ ] **Public SDK keys**: Project → **API keys** (Project settings). Each app has its own *public* key: **`appl_…`** for App Store and **`goog_…`** for Play. Hand them to the Flutter developer to put into `lib/config.dart`:
  ```dart
  static const revenueCatAppleKey = 'appl_xxxxxxxxxxxxxxxxxxxxxxx';
  static const revenueCatGoogleKey = 'goog_xxxxxxxxxxxxxxxxxxxxxxx';
  ```
  Public keys are safe to ship in the app. **Never** put a **secret** key (`sk_…`) or the `.p8`/JSON credentials in the app or in git.
- [ ] Do **not** turn on any RevenueCat third-party **integrations** (ad networks, analytics). The privacy policy and data safety answers assume none.
- [ ] Test on both platforms: buy yearly (trial) → `pro` active; restore on reinstall; cancel → expires; lifetime → `pro` active with no expiry. Check the customer in RevenueCat's dashboard ("Sandbox data" toggle).

---

## D. GitHub Pages for `docs/`

The app already points to `https://swalih60.github.io/Ticklist/…`, so the repo must be **`Ticklist` under the `swalih60` account** (GitHub usernames are case-insensitive in the URL; the repo path is case-sensitive, so keep "Ticklist").
- [ ] Push the project (or just the `docs/` folder) to `github.com/swalih60/Ticklist`.
  - GitHub Pages on a **private** repo needs a paid plan (GitHub Pro or higher). If the code repo stays private on a free plan, create a separate **public** repo named `Ticklist` that contains only `docs/`, or rename and update the URLs in `lib/config.dart`.
  - Never commit keystores, `.p8` files, the service-account JSON or `key.properties`.
- [ ] Repo → **Settings → Pages** → Source: **Deploy from a branch** → Branch `main`, folder **`/docs`** → Save.
- [ ] Wait 1–2 minutes, then open `https://swalih60.github.io/Ticklist/`, `/privacy.html` and `/terms.html`. Check that they load on a phone and in dark mode.
- [ ] (Optional) Custom domain later: Settings → Pages → Custom domain. If you change the domain, update the URLs in `lib/config.dart` and in both store consoles.
- [ ] Whenever the app's data practices change, update `privacy.html` and its "Last updated" date **before** releasing that version.

---

## E. Data safety (Google Play) and App Privacy (Apple)

Basis: the app stores tasks, notes and settings only on the device; backups are exported only when the user chooses; reminders are local notifications; no ads, analytics or crash SDKs; no account. The only off-device data flow is the **RevenueCat SDK** (configured at every app start when online), which sends an anonymous app user ID, purchase/receipt data and basic device info. The answers below follow RevenueCat's own docs ("Google Play's Data Safety" and "Apple App Privacy").

### E1. Google Play: Policy → App content → Data safety
| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **Yes** (because of RevenueCat) |
| Is all user data collected by your app encrypted in transit? | **Yes** |
| Which account creation methods does your app support? | **My app does not allow users to create an account** (the deletion-URL requirement for accounts then doesn't apply) |
| Do you provide a way for users to request that their data be deleted? | **Yes**: by email to support (privacy policy §7). RevenueCat customers can be deleted from its dashboard or REST API. |
| Data types | **Financial info → Purchase history** only |
| Collected / Shared | **Collected** (not shared; RevenueCat is a service provider acting for you) |
| Processed ephemerally? | **No** |
| Required or optional? | **Required** (users can't turn it off) |
| Purposes | **App functionality** and **Analytics** (RevenueCat's recommendation, which covers its dashboard charts) |
| Everything else (location, personal info, contacts, app activity, device IDs, app info and performance…) | **Not collected.** Task data stays on the device. Under Google's definition, data that never leaves the device is not "collected". The JSON export is user-initiated sharing to an app of the user's choice and is not collected by you. |

Notes: if you ever add RevenueCat integrations, set a custom App User ID, or add crash reporting or analytics, revisit this form *and* `privacy.html`. Device or other IDs would only apply if an advertising ID were used, and none is.

### E2. Apple: App Store Connect → App Privacy
- [ ] Data collection: **Yes, we collect data from this app**.
- [ ] **Purchases → Purchase History**: tick it.
  - Linked to the user's identity? **No** (RevenueCat uses an anonymous app user ID, and we have no accounts or emails).
  - Used for tracking? **No**.
  - Purposes: **App Functionality** and **Analytics**.
- [ ] **Identifiers → User ID**: **not** required (we don't set a custom App User ID). **Device ID**: not used (no IDFA).
- [ ] Everything else (Contact info, Health & Fitness, Location, Usage Data, Diagnostics, User Content…) → **not collected**. Tasks and notes are user content kept only on the device, so they are not "collected" in Apple's sense either.
- [ ] The resulting label should read: **"Data Not Linked to You: Purchases"**.
- [ ] Privacy manifest: the RevenueCat iOS SDK ships its own `PrivacyInfo.xcprivacy`. The Flutter developer should make sure the app target has one if any first-party "required reason" APIs are used (e.g. `UserDefaults`, file timestamps). ⚠ Check Xcode's generated privacy report before submitting.
- [ ] Do **not** add App Tracking Transparency; the app does not track.

---

## F. Final pre-submit sweep
- [ ] `support@EXAMPLE.com` replaced everywhere; `lib/config.dart` keys filled in (`storeConfigured` becomes true).
- [ ] Privacy and Terms URLs open from inside the app (paywall and settings).
- [ ] Paywall shows localised prices from RevenueCat (not hard-coded), the trial wording, auto-renew text, a Restore button, and the Terms/Privacy/EULA links.
- [ ] Free tier: unlimited tasks; repeat picker, Insights detail and non-default themes open the paywall; Pro unlocks them; after Pro lapses, the theme falls back to default and tasks remain.
- [ ] Quick add parses the store example exactly: "Gym tomorrow 7am !high #health" (it is in screenshot 2 and the promo text).
- [ ] Backup export → uninstall → reinstall → import round-trips correctly. This is critical, because there is no cloud copy.
- [ ] Reminders fire after a reboot (`RECEIVE_BOOT_COMPLETED` is declared) and across time-zone changes; on Android 13+ the notification permission prompt appears. The code uses `AndroidScheduleMode.inexactAllowWhileIdle` and the manifest declares no exact-alarm permission, so **no exact-alarm declaration is needed** in Play Console. Trade-off: Android may deliver reminders a few minutes late; keep the "don't rely on it for critical reminders" line in the Terms.

## Sources
- Google Play testing requirements for new personal accounts: support.google.com/googleplay/android-developer/answer/14151465
- Play developer account registration and verification: support.google.com/googleplay/android-developer/answer/6112435, /answer/13628312
- Target API level: developer.android.com/google/play/requirements/target-sdk
- RevenueCat: docs "Google Play's Data Safety", "Apple App Privacy", "In-App Purchase Key Configuration", "Google Play Service Credentials", "Offerings overview"
- Apple Standard EULA: apple.com/legal/internet-services/itunes/dev/stdeula/
