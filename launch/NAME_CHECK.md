# Name check: Ticklist and alternatives

Checked 21 Nov 2026 by web search (App Store and Google Play pages that search engines index) plus one App Store page fetch.

Limits of this check:
- Web search does not cover every store listing, and Google Play is indexed much less completely than the App Store. **Before you commit, search each name inside the App Store app and the Play Store app yourself**, in India and the US.
- This is **not** a trademark search. Search the Indian Trade Marks registry (ipindiaservices.gov.in), USPTO and EUIPO, class 9 (software) and 42.
- Domains and social handles were **not** checked.

---

## 1. "Ticklist": taken on iOS by a direct competitor, not recommended

| Existing app | Store | Notes |
|---|---|---|
| **TickList: To Do Daily Planner** (Swifty Brains LLP) | App Store (id6758654695) | Same name, same category (Productivity), same pitch: to-do list, daily planner, subtasks, priorities, reminders, themes, "TickList Premium" IAP ($6.99–$19.99). 22 ratings; v1.5 updated 20 Oct. Fetched and confirmed. |
| **Tick List: To-Do List & Tasks** (independent developer) | App Store (id6745620076) | Second to-do app with the same name, spaced. Listing mentions a "rebranding". |
| **Tick List Schedule Planner** (4 POWER PIXEL, `com.todolist.schedule.planner`) | Google Play (seen via AppGoblin, a third-party tracker; **not verified on play.google.com**) | Productivity, updated Mar 2026. |
| **Tick Day** (`com.app.tickday`), **TickUp** (`app.tickup`) | Google Play | Daily task trackers with "Tick" names; Tick Day is also pitched as privacy-first. |
| **TickTick** | Both stores | Market leader (about 5M Play downloads). "Ticklist" reads as a TickTick spin-off, which hurts trust and invites a trademark complaint. |

Conclusion: Apple requires a unique app *name*, so a bare "Ticklist" might be accepted, but users searching "ticklist" would see a competitor first, and the name is too close to TickTick. **Rename before launch.** Keep "Ticklist" as the code name (see §3).

## 2. Alternatives checked

All are 9 characters or fewer, so the title "<Name>: To Do List & Planner" fits in 30 characters.

| Name | Idea | Search result | Verdict |
|---|---|---|---|
| **Plandot** | Plan + the dot you tick. Short, two clear syllables, contains "plan". | No app named "Plandot" or "Plan Dot" found on either store. Nearby: **Dot Planner** (iOS), **Pladay: To Do List & Planner** (Play, 100+ downloads), **Plandy: Calendar & Tasks** (iOS). | **Recommended.** Clear in search, distinctive enough to trademark, and says "planner" without being generic. Risk: Pladay/Plandy are one or two letters away, so check the in-store search carefully. |
| **Checkmint** | Check + mint (fresh, clean) | No app found. Nearby: **CheckDot: Tasks** (iOS), **CheckNotes** (Play), **Spring Mint** to-do (iOS). | **Strong backup.** Most distinctive and easiest to protect. Weaker for keywords and slightly longer to say. |
| **Dayplot** | Plot out your day; fits the v1.1 timeline view | No app named "Dayplot" found. Nearby: **TaskPlot** (iOS, formerly DayWise+), **Daymint: Offline Daily Planner** (Play), **DayMap** (iOS). | OK. Clear today, but the "Day…" prefix is crowded with planners (Daymint is also offline-first), so it would blend in. |
| **Duely** | Tasks that are due, done duly | No exact match. **Duenly** (iOS task-card app) is one letter away. | Weak. Too close to Duenly, and easily misspelled as "Dually"/"Duly". |

Rejected during the search:
- **Daymark**: "Daymark Planner" (iOS, id6765720167) is a live daily planner with per-day pages and task forwarding, almost our exact concept. Also "DayMarks" and "Day Tracker: Daymark".
- **Doneday**: no exact match, but **Doday: Daily To-Do List** (iOS, $9.99/yr) is too close.
- **Tidyday**: no exact match, but "Tidy", "Daily Tidy" and "Tidywell" are cleaning/chore apps, so the name signals the wrong category.
- **Tickday**: "Tick Day" already exists on Google Play.

## 3. Recommendation

1. **Rename to Plandot** before launch. Store title **"Plandot: To Do List & Planner"** (29 characters). Use **Checkmint** if Plandot fails the in-store or trademark check.
2. Keep **Ticklist as the internal/code name**. The bundle ID / applicationId **`com.swalih60.ticklist`** never appears to users, so it does not need to change, and the policy URLs can stay at `https://swalih60.github.io/Ticklist/` (only the repo name shows in the URL). **Lock the bundle ID before the first upload**; it can never change afterwards.
3. This kit already uses "Plandot" in `launch/STORE_LISTING.md` and `docs/*.html`. If you rename, the Flutter developer changes `AppConfig.appName` in `lib/config.dart`, the paywall title ("Ticklist Pro") and the iOS/Android display names (`CFBundleDisplayName`, `android:label`). If you choose another name, find/replace "Plandot" in `launch/` and `docs/`.
4. Before deciding, do the checks this search could not: in-store search on both stores, a trademark search, a domain (`plandot.app` / `.in`) and an Instagram/X handle.

Sources: apps.apple.com id6758654695 (TickList, fetched), id6745620076 (Tick List), id6765720167 (Daymark Planner), id6473123694 (Doday), id1618495419 (Dot Planner), id6760203532 (CheckDot), id6768605774 (TaskPlot), id6756557264 (Duenly), id6736831438 (Plandy, via mwm.ai); play.google.com com.app.tickday, app.tickup, com.pladay.app, de.checknotes, developer "Daymint"; appgoblin.info com.todolist.schedule.planner.
