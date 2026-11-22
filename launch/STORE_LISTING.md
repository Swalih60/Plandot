# Store listing: Plandot (Play Store + App Store)

> "Ticklist" is the working name. NAME_CHECK.md explains why it should not ship under that name and recommends **Plandot**. Every title and subtitle below is written so that any 7–9 letter name (Plandot, Checkmint, Dayplot) can replace "Plandot" without breaking a character limit. If you keep a longer name, re-run the count.
>
> **Character counts** were measured with a script (Python `len`) on the exact text inside each code block on 21 Nov 2026. The limits used are App Store: name 30, subtitle 30, keywords 100, promotional text 170, description 4000; Google Play: title 30, short description 80, full description 4000. *(These are the long-standing limits from both consoles' help pages. The consoles enforce them as you type, so you'll see at once if one has changed.)*

---

## 1. Keyword research and reasoning

**Method and caveat.** We have no paid ASO tool, so the search volumes are **not measured**. The keyword choices come from (a) the titles and subtitles of the apps that ranked when searching the stores' web pages for to-do/planner terms (TickTick "To-Do List & Calendar", Todoist "To-Do List & Planner", Any.do "To do list & Planner", Structured "Daily Planner Todo", plus dozens of small "Daily Planner / To Do List" apps), and (b) the features we have that the big apps don't lead with: offline, no account, natural-language quick add. **After launch, check them**: Apple Search Ads → Keyword Planner (free popularity score) and Play Console → Grow users → Store performance → search terms.

| Tier | Terms | Why |
|---|---|---|
| Head (must have) | to do list, planner, to-do, tasks | The category's main search terms. Every top competitor's title contains "To-Do List" and/or "Planner". They go in the title on both stores. |
| Core secondary | daily planner, reminders, checklist, schedule, notes, organizer | Describe the core loop (plan today, get reminded, tick it off). "Daily" + "Planner" across name and subtitle let Apple combine them into "daily planner". |
| Differentiators (long-tail, lower competition) | offline to do list, private planner, no account, to do list no ads | Our real point of difference. The big apps need accounts and cloud sync and can't credibly claim these. |
| Feature long-tail | priority, subtasks, tags, recurring tasks, overdue, quick add, agenda, routine, productivity, goal, gtd | Real features we have. "gtd" is cheap to include and is a known niche term. |
| Avoid | "TickTick", "Todoist", "Things", "Any.do", "#1", "best", "free" in the title, emoji in the title | Third-party trademarks and promotional terms in metadata are rejected (App Store guideline 2.3.7, Play metadata policy). "Tick" alone is a generic word and is fine in the keyword field; "TickTick" is not. |
| Not yet | focus timer, pomodoro, timeline, time blocking | These are v1.1 features. Don't put them in store metadata until they ship (App Store guideline 2.3.1 and Play policy reject listing features the app doesn't have). Add them in the v1.1 update; they are strong keywords. |

**How each store indexes**
- **App Store** indexes the app name (30), subtitle (30) and keyword field (100). Each word only needs to appear once across these three, so **never repeat** a word from the name or subtitle in the keyword field. Separate with commas, **no spaces**. The description is **not** indexed.
- **Google Play** has no keyword field. It indexes the title, short description and **full description**. Use the main phrases naturally (the full description below uses "to do list" and "planner" 3 times each, plus "to-do" in the short description) and don't stuff.

---

## 2. Apple App Store

**App name (30 max)**: 29 characters
```
Plandot: To Do List & Planner
```

**Subtitle (30 max)**: 30 characters
```
Daily Tasks, Reminders & Notes
```

**Keyword field (100 max)**: 100 characters. No spaces; repeats no word from the name or subtitle (checked by script).
```
todo,checklist,offline,private,schedule,organizer,agenda,priority,routine,productivity,tick,goal,gtd
```

**Promotional text (170 max, can be changed any time without review)**: 134 characters
```
Plan your day in seconds. Type "Gym tomorrow 7am !high" and it's scheduled. No account, no ads, and your tasks never leave your phone.
```

**Description (4000 max)**: count in the table at the end of this section. Not indexed, so it is written for conversion.
```
Plandot is a calm, fast daily planner and to-do list. Write down what you need to do today, tick it off, and see tomorrow coming.

No account. No ads. No tracking. Your tasks are saved on your iPhone, not on our servers.

QUICK ADD THAT UNDERSTANDS YOU
Type "Gym tomorrow 7am !high #health" and Plandot sets the day, the time, the priority and the tag for you.

PLAN EACH DAY
• Tasks organised by day, with a simple date strip to move between days
• Priorities: High, Medium, Low or none, colour-coded at a glance
• Notes and subtasks for anything with more than one step
• Due times and reminders as local notifications
• Tags to group work, home, health or study
• Overdue tasks are easy to spot. Move them to today with one tap.
• A daily note for plans, journaling or end-of-day reflections
• Search across every task and note

PRIVATE BY DESIGN
• Works fully offline
• No sign-up, no email, no login
• No ads and no analytics
• Everything is stored in a file on your device
• Export a backup file any time and import it on a new phone

PLANDOT PRO
Everything above is free. Plandot Pro adds:
• Repeating tasks: every day, weekdays or weekly
• Insights: trends, best days and your priority breakdown
• Premium colour themes
• New Pro features as they arrive

Pro is available as a yearly subscription with a 7-day free trial, a monthly subscription, or a one-time lifetime purchase.

SUBSCRIPTION INFORMATION
• Payment is charged to your Apple Account when you confirm the purchase, or when the free trial ends.
• Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. Your account is charged for renewal within 24 hours before the end of the current period.
• You can manage or cancel your subscription in your Apple Account settings at any time.
• Any unused portion of a free trial is forfeited when you purchase a subscription.
• Lifetime is a one-time purchase and does not renew.

Privacy Policy: https://swalih60.github.io/Ticklist/privacy.html
Terms of Use: https://swalih60.github.io/Ticklist/terms.html
Apple Standard EULA: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/

Questions or ideas? support@EXAMPLE.com
```

**Other App Store fields**
- Primary category: **Productivity**. Secondary: **Lifestyle**. (Every direct competitor is in Productivity; there is no less-crowded category that fits honestly.)
- Age rating: answer "None" to every content question, which should give 4+.
- Support URL and Marketing URL: `https://swalih60.github.io/Ticklist/`
- Privacy Policy URL: `https://swalih60.github.io/Ticklist/privacy.html`
- License Agreement: keep Apple's **Standard EULA** (the default). The Terms and EULA links are in the description, as App Review expects for subscription apps (guideline 3.1.2).
- What's New (v1.0): `First release. Plan your day, offline and private.`

---

## 3. Google Play

**App name (30 max)**: 29 characters
```
Plandot: To Do List & Planner
```

**Short description (80 max)**: 79 characters
```
Daily planner & to-do list with reminders. Offline, private: no account, no ads
```

**Full description (4000 max)**: count in the table below.
```
Plandot is a simple, private to do list and daily planner. Plan today, tick tasks off, and never lose track of what's overdue.

No sign-up, no ads, no tracking. Your tasks are stored on your phone and are never uploaded to us.

★ QUICK ADD IN PLAIN WORDS
Type "Gym tomorrow 7am !high #health" and Plandot fills in the day, time, priority and tag. Writing a to do list has never been faster.

★ YOUR DAY, ORGANISED
Every day has its own list. Move between days with the date strip and see exactly what's planned.

★ PRIORITIES, NOTES AND SUBTASKS
Mark tasks High, Medium or Low. Add notes and break bigger jobs into subtasks.

★ REMINDERS
Set a due time and get a local notification when it matters. No server, no account.

★ OVERDUE? MOVE IT TO TODAY
Missed something? Overdue tasks stand out, and one tap moves them to today.

★ TAGS, DAILY NOTE AND SEARCH
Group tasks with #tags, write a daily note for plans or reflections, and search everything instantly.

★ PRIVATE AND OFFLINE BY DESIGN
• Works fully offline
• No account, no email, no login
• No ads and no analytics SDKs
• Your data stays in a file on your device
• Export a backup file any time and import it on a new phone

GREAT FOR
Work tasks, study plans, shopping lists, chores, workouts, appointments, bills, packing lists and daily routines. A to do list, daily planner, checklist, task manager and reminder app in one.

PLANDOT PRO
Everything above is free, with no limit on tasks. Plandot Pro adds:
• Repeating tasks: daily, weekdays or weekly
• Insights: trends, best days and priority breakdown
• Premium colour themes
• New Pro features as they arrive

Choose a yearly plan with a 7-day free trial, a monthly plan, or a one-time lifetime purchase. Subscriptions renew automatically until cancelled. You can cancel any time in Google Play → Payments & subscriptions. Cancel before the trial ends and you won't be charged.

Privacy Policy: https://swalih60.github.io/Ticklist/privacy.html
Terms of Use: https://swalih60.github.io/Ticklist/terms.html

Feedback and support: support@EXAMPLE.com

A calm planner for busy days. Download Plandot and plan today in seconds.
```

**Other Play fields**
- Category: **Productivity**. Tags: pick To-do list, Planner, Productivity from Play's tag list.
- Contains ads: **No**. In-app purchases: **Yes**.
- Contact email: support@EXAMPLE.com (placeholder; Play shows it publicly). Website: `https://swalih60.github.io/Ticklist/`.
- Feature graphic 1024×500: the Today list with a few ticked tasks and the app name; no device frame needed. No price, "#1" or "best" claims in the icon or feature graphic.

### Measured counts (script, 21 Nov 2026)

| Field | Limit | Count |
|---|---|---|
| App Store name / Play title | 30 | 29 |
| App Store subtitle | 30 | 30 |
| App Store keywords | 100 | 100 |
| App Store promotional text | 170 | 134 |
| App Store description | 4000 | 2,196 |
| Play short description | 80 | 79 |
| Play full description | 4000 | 2,136 |

---

## 4. Screenshot captions (6 screens, same order on both stores)

Big first line (5 words or fewer), small second line. Use realistic sample tasks with no personal names (e.g. "Gym", "Pay electricity bill", "Team standup", "Buy groceries").

| # | Screen shown | Headline | Sub-line | Keyword it supports |
|---|---|---|---|---|
| 1 | Today: tasks with priority colours, a couple ticked | **Your day, at a glance** | Plan today. Tick it off. Feel the progress. | daily planner, to do list |
| 2 | Quick add sheet mid-typing "Gym tomorrow 7am !high #health" with parsed chips | **Just type it** | "Gym tomorrow 7am !high" sets the day, time and priority | quick add, schedule |
| 3 | Task editor: notes, subtasks, due time, reminder on | **Every detail, one place** | Notes, subtasks, tags and reminders | reminders, checklist |
| 4 | Overdue section with the "Move to today" button | **Missed it? Move it.** | One tap brings overdue tasks to today | overdue, organizer |
| 5 | Insights (Pro) + a repeat picker inset | **Build routines that stick** | Repeating tasks and insights with Pro | routine, productivity |
| 6 | Settings/backup screen or a lock graphic | **Private. Offline. No account.** | No ads. No tracking. Your tasks stay on your phone. | offline, private |

Sizes: iOS 6.9" (1320×2868 or 1290×2796). **The iOS project currently targets iPhone and iPad** (`TARGETED_DEVICE_FAMILY = "1,2"`), so App Store Connect will also require 13" iPad screenshots (2064×2752 or 2048×2732) unless the Flutter developer makes the app iPhone-only. Play: phone screenshots at least 1080 px on the short side, 9:16. *(Verify the current required sizes in each console when uploading.)*

After launch, use Play "Store listing experiments" to test screenshot 2 (quick add) as the first screenshot. It is the most distinctive thing the app does.

---

## 5. Pricing

### Competitor prices found (App Store web pages, US and India storefronts, 21 Nov 2026)

| App | Monthly | Yearly | Lifetime / one-time | Notes |
|---|---|---|---|---|
| **TickTick** Premium | $4.99 / ₹269 | $49.99 / ₹2,599 | none | Clear single tier. |
| **Todoist** Pro | $6.99 / ₹330 | $59.99 / ₹3,149 | none | "Legacy" products show the same prices. |
| **Things 3** | none | none | iPhone $9.99 / ₹999; iPad $19.99 (Mac sold separately) | Paid upfront, no IAP, iOS only. |
| **Structured** Pro | $2.99–$7.99 / ₹89–₹299 | $9.99–$49.99 / ₹279–₹999 | $99.99 / ₹899–₹950 | Ten IAP entries listed; **the main tier can't be told from the page** (probably $34.99–$49.99/yr in the US, with old/intro tiers mixed in). India is priced far below the US. |
| **Any.do** Premium | $5.99–$9.99 / ₹419–₹489 | $59.99 / ₹2,549–₹4,899 | none | Many discount products listed ("50% off" yearly at $17.99–$22.99 / ₹1,249). Main tier inferred, not certain. |

Google Play prices were **not** checked (Play does not show IAP prices on its web pages). They are usually similar.

### Suggested launch prices

Positioning: a new, independent, privacy-first planner with no reviews yet and fewer features than TickTick or Todoist (no sync, no calendar, no collaboration). Price **well below the big subscription apps** and close to Things' one-time price, with the trial-backed yearly plan as the highlighted default.

| Product (RevenueCat package) | USD (US) | INR (India) | Notes |
|---|---|---|---|
| Yearly, 7-day free trial (`$rc_annual`) | **$14.99** | **₹699** | Default, highlighted. About 30% of TickTick's yearly price in both countries. "Save 58%" vs monthly in the US, 61% in India. |
| Monthly (`$rc_monthly`) | **$2.99** | **₹149** | Mainly an anchor that makes yearly look good. |
| Lifetime (`$rc_lifetime`) | **$34.99** | **₹1,499** | About 2.1–2.3× yearly. Indian buyers compare with Things (₹999) and Structured lifetime (₹899–₹950); if lifetime sales are weak in India, test ₹999. |

Notes:
- Indian store prices **include GST**; Apple and Google withhold or remit it, so you receive less than the sticker price after tax and commission. Google Play takes 15% on subscriptions and on the first US$1M/year of other sales. Apple takes 15% only if you enrol in the Small Business Program (not automatic); otherwise 30% on first-year subscriptions and the lifetime IAP. *(Check current terms in each console.)*
- **Apple** uses fixed price points per storefront. Pick the nearest point to ₹699 / ₹149 / ₹1,499 and override India manually rather than relying on automatic equalisation from the US price. **Not checked against the current price table**; ₹699 in particular may not be a point, in which case use ₹649 or ₹749.
- **Google Play** allows any price per country. Set USD as the default and override India manually; the automatic conversion would land much higher than ₹699.
- Re-evaluate after about 1,000 paywall views (₹499 vs ₹699 vs ₹999 yearly in India is the most useful test).
