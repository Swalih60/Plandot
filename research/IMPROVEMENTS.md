# Ticklist: Improvement Research (Nov 2026)

What makes best-in-class task apps feel premium, and what Ticklist should copy. Values marked *(suggested)* are our own design choices. They were not measured from another app.

**What reviewers keep praising:**
- **Things 3:** animations described as "flawless". The draggable Magic Plus button is fun to use, and the app has a separate "This Evening" section.
- **TickTick:** focus timer, Eisenhower matrix and habits, all in one app.
- **Structured / Tiimo:** a single vertical timeline of the day, with colour and icons. Tiimo was iPhone App of the Year 2025.
- **Sunsama:** daily planning and "shutdown" rituals.
- **Amie:** warm minimalism and colour-coded scanning.

**Common complaints:**
- Things 3's animations can slow down typing.
- TickTick hides its power features in settings.
- Planner apps get abandoned once the user skips the ritual for a few days.

---

## 1. Features to add (value ÷ effort, highest first)

| # | Feature | Value | Effort | Pro? | Notes |
|---|---|---|---|---|---|
| 1 | **Natural-language quick add** (`Call mom tomorrow 5pm !high #family every week`) | ★★★★★ | M | Free | Highlight parsed tokens as chips while the user types, the way Todoist does. Write a small Dart tokenizer for: today/tom/weekday/"in 3 days", times, `!high/!med/!low` (also `!1–3`), `#tag`, `every …`. Have it fall back gracefully when it can't parse something. |
| 2 | **Home-screen widgets** (Today list, plus an interactive checkbox) | ★★★★★ | M–H | Small widget free, others Pro | Use `home_widget`. The UI has to be native: WidgetKit with AppIntent on iOS 17+, Glance on Android. |
| 3 | **Swipe actions + drag to reschedule** (drag onto a date strip) | ★★★★☆ | M | Free | Structured's swipe-to-"Replan" for missed tasks is a loved feature. Add a one-tap **"Move overdue to today"**. |
| 4 | **Timeline / day view** (tasks with due times shown as blocks on a vertical line) | ★★★★☆ | M–H | Pro | This is the core of Structured and Tiimo. Use colour and an icon per task. |
| 5 | **Focus timer** (Pomodoro on any task; minutes logged to stats) | ★★★★☆ | M | Pro (basic 25/5 free) | TickTick reviewers call it "a game-changer". Show it as a Live Activity or ongoing notification later. |
| 6 | **Daily planning + evening shutdown ritual** (morning: pick today's tasks; evening: review, carry over, write a reflection into the daily note) | ★★★★☆ | M | Free | Sunsama's signature. It reuses the daily note we already have. Keep it skippable so it doesn't feel like a chore. |
| 7 | **Streaks + "done today" ring** | ★★★☆☆ | L | Free | Low effort, high motivation. Use a gentle streak freeze so one bad day doesn't erase progress. |
| 8 | **Templates / routines** (Morning routine, Packing list) | ★★★☆☆ | L–M | Pro | Structured puts routines in Pro. |
| 9 | **Eisenhower matrix view** | ★★★☆☆ | L | Pro | Map the existing priority + due date onto 4 quadrants. Drag between quadrants to change priority. |
| 10 | **"This Evening" / time-of-day buckets** | ★★★☆☆ | L | Free | Things 3 favourite. Cheap to build. |
| 11 | **Themes + app icons** | ★★☆☆☆ | L | Pro | Classic premium unlock. |
| 12 | **Encrypted local backup/export** (JSON/ICS to Files) | ★★★☆☆ | L | Free | Offline users worry about losing data. |
| 13 | **Habits** | ★★☆☆☆ | H | Later | Scope creep. Repeat + streaks covers most of it. |

## 2. Visual style

**Direction:** warm minimalism, in the Amie/Things style. Depth should come from layered surfaces, not heavy shadows. Use one confident accent colour, and give priority colours their own meaning.

**Light palette** (Amie-measured neutrals + suggested accents):
- Background `#FAFAFA` (not pure white)
- Surface/card `#FFFFFF` on `#F2F2F2` grouped areas
- Text: primary `#171717`, secondary `#5C5C5C`, tertiary `#A0A0A0`
- Accent *(suggested)* `#4F6BED` indigo-blue
- Success `#22C55E`
- Priorities *(suggested)*:
  - High `#F2545B`
  - Medium `#F5A524`
  - Low `#4F8EF7`
  - None `#A0A0A0`
- Tag colours: Amie-style scale, e.g. Rose `#FF2B5F`, Orange `#FE6600`, Yellow `#F4AF00`, Green `#01CA45`, Teal `#14B8A6`, Indigo `#6366F1`, Violet `#8B5CF6`, Pink `#FF329A`. Use them at 12% opacity for chip backgrounds.

**Dark palette** *(suggested)*:
- Background `#0E0E10`, surface `#18181B`, elevated `#232327`
- Text `#F4F4F5` / `#A1A1AA` / `#71717A`
- Lift the accent to `#7088FF`
- Avoid pure black, except in an optional OLED theme (Pro)

**Typography:**
- Font: Inter, or the system font (SF Pro / Roboto Flex). Inter is what Amie uses.
- Large title 32/38 w700 with tracking −0.5
- Section header 13 w600, uppercase, letter-spacing +0.6, tertiary colour
- Task title 16/22 w500
- Meta 13/18 w400
- Use tabular figures (`FontFeature.tabularFigures()`) for times and stats

**Spacing & shape:**
- 4 pt grid: 4/8/12/16/24/32
- Screen gutter 16–20
- Task row min height 52, vertical padding 12
- Radii: cards 16, sheets 28 (top corners), chips 999 (pill), checkbox 7 (rounded square) or circle
- Shadows: `0 1 2 rgba(0,0,0,.04)` plus `0 8 24 rgba(0,0,0,.06)`, and only on floating elements (FAB, sheets)

**Iconography:**
- One family only, 1.75 px stroke, 24 px. Lucide (`lucide_icons`) or Phosphor (`phosphor_flutter`).
- Filled variants only for the selected state.

## 3. Animations & micro-interactions

**Rules:**
- 150–300 ms for UI changes; under 100 ms for press feedback.
- Use springs for anything the user drags or throws.
- Never block typing. Things 3 users complain about exactly this.
- Respect `MediaQuery.disableAnimations` (reduced motion).

| Moment | What animates | Flutter hint |
|---|---|---|
| **Checkbox complete** | Press: scale 1→0.88 (80 ms). Release: fill sweeps in plus the checkmark path draws (≈180 ms, easeOutCubic), then overshoots 1→1.12→1 on a spring. | `CustomPainter` with `PathMetric.extractPath` for the tick. `SpringSimulation(SpringDescription(mass:1, stiffness:400, damping:18))`. `HapticFeedback.lightImpact()` on press, `mediumImpact()` on completion. |
| **Strikethrough** | Line draws left→right across the title (220 ms, starting 60 ms after the tick). Text fades to tertiary colour. | `TweenAnimationBuilder<double>` driving a painter under the `Text`. `AnimatedDefaultTextStyle` for the colour. |
| **Move to Completed** | Wait ~600 ms (gives the user time to undo), then the row collapses its height (250 ms easeInOut) and reappears in Completed. | `AnimatedList.removeItem` + `SizeTransition` + `FadeTransition`. Use a `SnackBar` for "Undo". |
| **List reorder** | Long-press lifts the row: scale 1.03, shadow up, `selectionClick` haptic. Neighbours slide out of the way. | `ReorderableListView` with a `proxyDecorator` for the lift. `HapticFeedback.selectionClick()` on each slot change. |
| **Swipe actions** | The action colour is revealed under the row. The icon scales up when it crosses the 40% threshold, with a haptic tick at the threshold. Full swipe commits. | `flutter_slidable` (`DismissiblePane`). Fire `HapticFeedback.mediumImpact()` once, when the threshold is crossed. |
| **Celebration** | The last task of the day gets a confetti burst from the checkbox (≈1.2 s) and an "All done" card. Keep it rare: once per day at most, and the user can turn it off. | `confetti` package (`ConfettiWidget`), positioned with a `GlobalKey`. Or a Lottie of ≤40 KB. `HapticFeedback.heavyImpact()`. |
| **Empty states** | The illustration floats gently (translateY ±4 px, 3 s loop) and the copy fades in after a 100 ms stagger. | `flutter_animate`: `.animate(onPlay: (c)=>c.repeat(reverse:true)).moveY(begin:-4,end:4,duration:3.s)`. |
| **List entry** | Rows fade in and slide up 8 px with a 30–50 ms stagger. Amie uses 300 ms with a 50 ms stagger. Only do this on first load, never on every rebuild. | `flutter_animate` `.fadeIn(300.ms).slideY(begin:.08)` with `delay: (i*40).ms`. |
| **FAB → add sheet** | The FAB container morphs into the quick-add card with the keyboard focused, ~300 ms. | `animations` package `OpenContainer(transitionType: fadeThrough, transitionDuration: 300ms)`. Autofocus the field *before* the animation ends. |
| **Task → detail** | Shared-element title/checkbox. | `Hero` on the checkbox + title, or `OpenContainer`. |
| **Page/tab transitions** | Fade-through between tabs (Today/Calendar/Stats). Shared-axis X when moving between days. | `PageTransitionSwitcher` + `FadeThroughTransition` / `SharedAxisTransition` from `animations`. |
| **Day switcher** | The selected-date pill slides between days on a spring. | `AnimatedPositioned` + `Curves.easeOutBack`, or `flutter_animate` `.custom` with a spring. |
| **Stats / ring** | The progress ring sweeps to its value (600 ms, easeOutCubic). Numbers count up. | `TweenAnimationBuilder`. |
| **Priority change** | The colour bar cross-fades and a selection haptic fires. | `AnimatedContainer(duration: 200ms)`. |

## 4. Onboarding & paywall

**Benchmarks:**
- About 82% of trial starts happen on install day.
- Onboarding-placed paywalls convert about 2x better than in-app gates (1.78% vs 0.89% install→paid, Adapty).
- Hard paywalls reach 10.7% trial→paid vs 2.1% for freemium, but they also bring more refunds (RevenueCat).
- For a free-core offline app, use **freemium with an onboarding paywall that can be dismissed**.

**Onboarding (≤60 s):**
1. One value screen, showing an animated demo of quick add plus a checkbox completing.
2. Personalise: "What do you plan?" (Work / Study / Home / Health) to seed tags, and "When do you plan your day?" to set the morning-planning reminder time.
3. Ask for notification permission *in context*, after the user has made their first task that has a time.
4. Let the user type a first task straight away. Its first completion triggers the celebration, so the "aha" moment comes before the paywall.
5. Paywall.

**Paywall:**
- Annual plan pre-selected, with "≈$X/month" shown under it. Monthly as the alternative. Optionally a lifetime plan, which offline users love and Structured offers.
- 7-day trial with a **trial timeline**: Today → Day 5 reminder → Day 7 billed. Then actually send the Day 5 reminder.
- Show 3–4 benefit rows with icons: Widgets, Timeline, Focus stats, Themes. Avoid a feature-grid wall.
- Add a soft "Not now" after a 2–3 s delay.
- Later, show contextual paywalls at the point of desire: tapping a locked widget size or theme previews it live, then upsells.
- Tooling: RevenueCat `purchases_flutter` + Paywalls. It handles receipts without a backend.
- Amie gets criticised for asking before showing value. Don't put the paywall before the first task.

## 5. Top 10 — do these next

1. **Checkbox + strikethrough + haptics polish.** It's the interaction users repeat 20 times a day.
2. **Natural-language quick add** with live token chips.
3. **FAB → quick-add `OpenContainer`**, with keyboard-first input that never waits on the animation.
4. **Swipe actions** (complete / reschedule / delete) plus **"Move overdue to today"**.
5. **Design tokens:** the palette, type scale, radii and dark theme above, as `ThemeExtension`s.
6. **Today widget**, small and medium, with an interactive checkbox on iOS 17+ and Android.
7. **Onboarding + RevenueCat paywall** with trial timeline and Day-5 reminder.
8. **Streak + daily progress ring**, with a once-a-day confetti on "All done".
9. **Timeline day view** (Pro).
10. **Focus timer** linked to tasks and stats (Pro), followed by the morning planning / evening shutdown ritual.

---

### Sources
- Things 3 review (MacStories): https://www.macstories.net/reviews/things-3-beauty-and-delight-in-a-task-manager/
- Things 3 features: https://culturedcode.com/things/features/
- Things 3 user comments: https://www.producthunt.com/p/things-3/things-3-0
- Things/TickTick/Todoist comparisons: https://dev.to/pickuma/todoist-vs-ticktick-vs-things-3-task-managers-developers-actually-stick-with-3gol · https://www.morgen.so/blog-posts/todoist-vs-things-3 · https://clickup.com/blog/ticktick-vs-things3/
- TickTick reviews: https://www.g2.com/products/ticktick · https://appleinsider.com/articles/23/01/10/ticktick-6420-review-prioritized-to-do-list-with-focus-timer · https://www.androidauthority.com/keep-coming-back-to-ticktick-3719344/
- Todoist Quick Add: https://www.todoist.com/help/articles/use-task-quick-add-in-todoist-va4Lhpzz
- Structured: https://apps.apple.com/app/structured-daily-planner/id1499198946
- Tiimo (App of the Year 2025): https://www.tiimoapp.com/resource-hub/tiimo-finalist-2025-app-store-awards · https://daringfireball.net/2025/12/2025_app_store_award_winners · https://www.techradar.com/computing/websites-apps/timo
- Sunsama rituals: https://www.sunsama.com/features/daily-planning-and-shutdown · https://www.asianefficiency.com/schedule-management/sunsama-review/
- Amie design system: https://blakecrosley.com/guides/design/amie · https://screensdesign.com/showcase/amie-todos-calendar
- Micro-interactions: https://www.elpassion.com/blog/what-are-micro-interactions-in-ux · https://uxplanet.org/micro-interactions-in-ios-creating-apps-that-feel-better-70a4c4470831 · https://hackathon.swmansion.com/blog/how-haptic-feedback-affects-sales-trust-and-product-perception/
- Flutter: https://docs.flutter.dev/cookbook/animation/physics-simulation · https://pub.dev/packages/flutter_animate · https://pub.dev/packages/animations · https://pub.dev/packages/confetti · https://pub.dev/packages/flutter_slidable · https://pub.dev/packages/home_widget
- Paywall benchmarks: https://www.revenuecat.com/blog/growth/subscription-app-trends-benchmarks-2026.md · https://www.airbridge.io/en/blog/paywall-conversion-structural-decisions · https://saastr.com/the-top-10-learnings-from-revenuecats-state-of-subscription-apps-how-115000-mobile-apps-deliver-16b-in-revenue-whats-working-whats-quietly-killing-growth
