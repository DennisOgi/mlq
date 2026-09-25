# MLQ UI Revamp — Implementation Plan (v2)

Built on the "UI Revamp Implementation Guide" and the Final Visual Reference Pack. The direction is unchanged: act → learn → progress → earn → celebrate, with the MLQ purple, violet and gold identity. This version:

- settles the points where the guide and the mockups disagree,
- fixes the parts of the mockups that don't match the app or its data,
- turns the guide into tokens, components and phases the codebase can follow.

Illustration prompts are in [`ILLUSTRATION_PROMPTS.md`](./ILLUSTRATION_PROMPTS.md).

---

## 1. Decisions this plan makes

| Topic | Guide / mockups | Decision |
|---|---|---|
| Bottom nav | Guide: 5 tabs (Home, Goals, Challenges, Victory, Ranks). Mockups: 6 tabs, one with Courses, one with Library | **5 tabs, as the guide says.** Profile and settings move to the avatar in the Home header. Courses, Library, Wallet and Questor are reached from Home. |
| Questor | Mockups show a caped, goggled robot with a "Q" on the chest | **Use the existing Questor** (`assets/images/questor*.png`): mustard and coral robot, round eyes, antenna, spring legs. New poses must match it. |
| Illustration style | Glossy, painterly 2.5D | **Storybook style with thin ink outlines and soft cel shading**, so the scenes and Questor look like one family. See the prompt pack. |
| Amount of art | Custom art on nearly every card and header | **11 new images** (8 topic covers + 3 goal covers). Everything else reuses the existing Questor poses and badges, or is drawn in code. |
| Cast | One boy on almost every screen | **No fixed recurring characters.** Each cover shows one Nigerian student aged 11 to 16. A shared style and palette keep the set consistent. |
| Library categories | Personal Growth / Leadership / Wellbeing / Faith & Values; filters for Videos, Books, Audio, Worksheets | **Use what we actually have**: subjects are Languages, Maths, Biology, Chemistry, Physics, English, History, Health & Wellness and General. Only show a format filter when content exists (today: Video, plus PDF in School). |
| Ranks tabs | Guide: Weekly / Monthly / Community | **Weekly / Monthly / My School.** Communities were removed, so My School stands in for Community. Weekly can be computed from `xp_awards` (live, per-award timestamps) but needs a new leaderboard query. |
| Dark screens | The School library currently uses charcoal and gold | **Move to the light system** (cream body, purple header). Only the video stage stays dark. |
| Green | Small success states only | Kept. Checkmarks, "Completed" pills and correct quiz answers only. |

---

## 2. Design tokens

Replaces `AppColors` in `lib/constants/app_constants.dart` and the theme in `lib/theme/app_theme.dart`. Change the tokens first, then check each screen.

### Colour

| Token | Hex | Use |
|---|---|---|
| `plum900` (Deep Purple) | `#40003D` | Header gradient start, secondary buttons, headings on cream |
| `violet700` (Royal Violet) | `#652D6D` | Header gradient end, active tab fill, icons |
| `violet500` | `#8A4F92` | Progress track fill, inactive icons on purple |
| `lilac100` (Light Lilac) | `#F3EAF6` | Chips, tertiary buttons, inactive tabs, section tints |
| `cream50` (Cream White) | `#FFF9F0` | Screen background |
| `surface` | `#FFFFFF` | Cards on cream |
| `gold400` (Quest Gold) | `#D7C16E` | **Fills only**: primary buttons, XP/coin pills, progress bars, highlights |
| `gold600` | `#B8962E` | Gold button pressed state, gold icon strokes |
| `gold800` | `#6E5500` | **Gold text** on cream or white (passes contrast). Never put `gold400` text on light backgrounds. |
| `ink900` | `#221431` | Body text |
| `ink600` | `#6B5A73` | Secondary text |
| `line` | `#EADFEE` | Card borders and dividers |
| `success` | `#2E9D5B` | Small success states only |
| `danger` | `#C0392B` | Errors and deadlines under 24 h only |

Retire `#9D0389` (magenta) and `#E6B800` (bright gold). They are why the app looks pink rather than plum.

**Header gradient:** `plum900 → violet700`, top-left to bottom-right, with a 28 px curve or rounded bottom edge where it meets the cream body.

### Type

Keep **Poppins** for headings and **Nunito** for body text.

| Style | Size / weight | Use |
|---|---|---|
| `display` | Poppins 28 / 800 | Screen title in the header |
| `title` | Poppins 20 / 700 | Section headers ("Continue Learning") |
| `cardTitle` | Poppins 16 / 700 | Card titles (max 2 lines) |
| `body` | Nunito 15 / 600 | Descriptions (max 2 lines on cards) |
| `caption` | Nunito 13 / 700 | Meta text, pills |
| `micro` | Nunito 12 / 800, +0.6 tracking, uppercase | Eyebrows ("ACADEMIC GOAL") |

Nothing below 12 px. Several mockup descriptions are around 11 px, which is too small for a phone.

### Shape and spacing

- Spacing scale: 4, 8, 12, 16, 20, 24, 32. Screen side padding is 20. Space between cards is 12.
- Radius: cards 20, image corners inside cards 16, buttons 14, chips and pills fully rounded.
- Shadow: one soft card shadow (`plum900` at 8%, blur 16, y 6). No glows except the gold CTA.
- Tap targets: at least 44 px high.

### Buttons (one set app-wide)

| Variant | Look | Use |
|---|---|---|
| **Primary** | `gold400` fill, `plum900` text, trailing chevron | The single main action on a card or screen (Update Goal, Continue, View Wallet, Redeem) |
| **Secondary** | `plum900` fill, white text | Main action on a gold or cream feature card (Join Challenge, Create a New Goal) |
| **Tertiary** | `lilac100` fill, `violet700` text, small | See All, Manage, filters |
| **Outline** | 1.5 px `line` border, `ink900` text | Cancel, Back, less important actions |

Rule: **no more than one gold button in view per card, and ideally one per viewport.** The Goals mockup shows four competing buttons.

### Icons

Use Material Symbols Rounded (outline for inactive, filled for active) everywhere. Keep illustrated or 3D icons for Questor's quick-start tiles, Library categories and rewards only.

---

## 3. Shared components (build before screens)

Add to `lib/widgets/mlq_ui_primitives.dart`, or split into `lib/widgets/mlq/`.

| Component | Notes |
|---|---|
| `MlqHeroHeader` | Purple gradient, curved bottom, title (optional gold word: "My **Goals**"), subtitle, right-side art slot (illustration or Questor), optional stat strip or tabs overlapping the bottom edge. Max height about 30% of the viewport. |
| `MlqCard` | White surface, radius 20, `line` border, soft shadow, optional image header |
| `MlqButton.primary / secondary / tertiary / outline` | See §2 |
| `MlqSegmentTabs` | Pill tabs. Active tab is `plum900` with white text on cream, or `gold400` with plum text on the purple header. Never truncate labels. |
| `MlqSectionHeader` | Icon + title + tertiary "See All" |
| `MlqProgressBar` | 8 px, rounded, gold fill on `lilac100`, optional % label |
| `XpPill`, `CoinPill` | Small pills with icon and value. XP is violet, coins are gold. |
| `MlqEmptyState` | Illustration, one line, one button |
| `MlqQuestorFab` | Circular Questor avatar (face cropped from the existing `questor.png`), bottom right, 56 px. Sits above the nav. Hides when scrolling down and returns when scrolling up. Must never cover a CTA. |
| `MlqBottomNav` | 5 items, active item gets a `lilac100` pill behind the icon and label |

---

## 4. Screens — hierarchy and my notes on the mockups

### 4.1 Home — top of screen

The top-of-screen mockup (01) isn't in the pack. Build it from the guide.

1. **Header (purple):** avatar (opens profile/settings) · "Hi, Tobi 👋" · level badge · streak 🔥 · notifications bell.
   A stat strip overlaps the curve with **XP to next level** (progress bar), coins and badges. Each item is tappable.
2. **Today's Quest (large gold-edged card):** one next action, with art, one line and a primary button. The choice follows a simple rule, not AI (see §5).
3. **Core shortcuts:** three equal tiles, Goals · Challenges · Victory, each with icon, label and a live count ("2 active").
4. **My Main Goal:** Academic / Social / Health tabs, then one goal card (art, title, progress, "Update Goal").

### 4.2 Home — scroll (mockup 02)

Order: Continue Learning → Lead Wallet → Rank preview → Digital Library.

What works: compact goal card, the three course cards in a row, the gold "View Wallet" CTA, and the Library placed low.

Changes:

- **Course cards:** show **XP only** on the card, not XP plus coins. Two reward pills plus a subtitle in a third-width card is too crowded. Add a thin progress bar and a "Completed ✓" state. Tapping opens the course; drop the play button overlay because these are lessons, not videos.
- **Wallet card:** swap in the real Questor (existing presenting pose) next to the coin art we already have. Show balance plus "+120 this week" to make the link between effort and reward clear.
- **Add the Rank preview** (missing from the mockup): "You're #7 at Wellspring · 140 XP to pass Isabella", with a tertiary "View Ranks". No list.
- **Library teaser:** keep it. Use real items (latest School lesson if the student has a school, otherwise one Explore video).
- **Bottom nav:** 5 tabs as in §1. The mockup's Courses tab is not used.

### 4.3 Mini Courses (mockup 03 missing)

- Header: "Today's **Quests**" + "3 courses · 300 XP available today".
- Three large cards, one per daily course: topic cover art (one of the 8 topic covers in the prompt pack), topic eyebrow, title, "3 lessons · 5 min", progress, Start/Continue/Review.
- Below them: "Past courses" as a compact list and "School courses" if the school has any.

### 4.4 Mini Course lesson (mockup 04 missing) — see §6

### 4.5 Goals (mockup 05)

What works: header with tabs and stat strip, a focused main goal with a checklist, a single "Create a New Goal" at the bottom.

Changes:

- **Too many CTAs.** Keep one gold "Update Progress" on the focused goal. The two smaller goal cards become tap-to-open cards with a progress bar and no buttons.
- **Pink Health colour** is off-brand. Each category keeps its icon, and all categories share violet and lilac tints. (Academic = graduation cap, Social = people, Health = heart.)
- The tabs in the header and the Social and Health cards repeat each other. Choose one: tabs *filter* the list, or cards *preview* the other categories. Recommendation: tabs filter, and each category shows its own main goal plus that category's daily goals.
- "Due Apr 30" is only shown if the goal has a deadline.
- Add a "Today's check-in" row (daily goals as tappable chips) under the main goal. That's the everyday action.

### 4.6 Challenges (mockup 06)

What works: art-led cards, reward and deadline visible, a clear Join button.

Changes:

- **Tabs:** "Active / My Challenges" is ambiguous. Use **Open · Joined · Completed**.
- **Layout:** the 50/50 image and text split truncates at 360 dp widths. The first (featured) challenge uses full-width art on top at 16:9. The rest are compact rows with an 88 px square art, title, reward pills and deadline, plus a chevron. Join happens on the detail screen.
- **Deadline colour:** `ink600` normally, `danger` only under 24 h.
- **Participant avatars:** only show them if we have the count. Otherwise show "Premium" or "Sponsored by X" (we have `sponsor_id` and `organization_logo`).
- Our challenges are mostly habit milestones (gratitude streaks, goal streaks, course collector, vision board). Challenge cards use the matching existing badge art (e.g. `flame_of_gratitude.png`, `goal_voyager.png`, `step_climber.png`) on a gradient, so they need no new illustrations.
- Joined challenges show a progress bar ("12 / 21 days").

### 4.7 Lead Wallet (mockup 07)

What works: big balance, Overview / History / Redeem tabs, gold Redeem buttons.

Changes:

- **Drop the "Available" tile.** It repeats the balance. Keep **Total earned** and **Redeemed**.
- **Recent earnings is missing** (the guide lists it as a priority). Under the stats show the last 5 earnings, "+50 · Finished *Talk Smart* · Today", then "See history".
- Put the "Unlock Amazing Rewards" goal bar right under the balance ("550 coins to your next reward"), and move featured rewards below it.
- Respect `WALLET_HIDDEN_FOR_WEB`: the web build must not show the wallet entry points.

### 4.8 Digital Library (mockup 08)

What works: rich once opened, search at the top, featured item, format badges.

Changes:

- **Explore | My School** segment under search (School only when `user.schoolId` is set). This replaces today's chips.
- **Categories = real subjects**: Languages, Maths, Biology, Chemistry, Physics, English, History, Health & Wellness. Faith & Values has no content, so it isn't used.
- **Filters:** only formats that exist. Explore today is all video, so hide format filters there. My School shows Video · Notes (PDF).
- **Featured:** a rotating Explore playlist, or the latest School lesson in My School. The featured art must not contain rendered book titles (see prompts).
- **My School home:** a school header (school name, "14 lessons", class filter chips JSS1 · JSS2 · SS1 · SS2), then week cards with Watch and Notes buttons, on the light theme.
- Keep the watch limit and lock state for Explore.

### 4.9 Victory Wall (mockup 09 missing)

- Composer at the top: avatar, "Share a win…", and three quick chips (📸 Photo · 🏆 Achievement · 😊 Feeling).
- Achievement posts use a generated card (badge art, "Tobi completed a 7-day goal streak") so posts look good without photos.
- Reactions row plus comments count. No community tags (Communities removed).

### 4.10 Ranks (mockup 10)

What works: strong podium, the student's own row highlighted in gold, clean rows.

Changes:

- **Tabs:** Weekly · Monthly · My School (see §1).
- **Avatars:** real users have photos or none. Design the podium for photo circles with an initials fallback. Crown and medals are overlays; no illustrated kids on the podium.
- **Pin the student's own row** to the bottom above the nav when it's scrolled out of view.
- The header shows "Resets in 6 days" for Monthly.
- Remove the repeated "My Leadership Quest" and "Monthly Leaderboard" headers. One title is enough.

### 4.11 Questor (mockup 11)

What works: quick starts first, chat second.

Changes:

- **Real Questor art** (waving pose in the header).
- Quick-start tiles: Set a Goal · Motivate Me · Explain Today's Lesson · Solve a Problem · Build Confidence. They scroll horizontally, 5 tiles, each with a small illustrated icon. Use lilac for all tiles instead of five different colours.
- **Answers are text only.** No sticker inside the reply bubble; it takes space and repeats the header.
- Show the coin cost next to the input if the rule still applies ("2 coins per message").
- The chat input sits above the keyboard. The FAB is hidden on this screen.

---

## 5. Today's Quest rule

Choose the first item that applies:

1. A mini course **in progress** today → "Finish *{title}* · +{xp} XP" → Continue.
2. A daily course **not started** → "Start today's quest: *{title}*" → Start.
3. Today's goal **check-in** not done → "Check in on *{goal}*" → Check In.
4. A joined challenge ending within 48 h → "*{challenge}* ends tomorrow" → View Challenge.
5. Gratitude jar entry not made today → "Add one thing you're grateful for" → Open Jar.
6. Everything done → celebration card "All quests done today! 🎉" with streak count.

All the data already exists (daily courses, goal check-ins, user challenges, gratitude). No backend work is needed.

---

## 6. Mini Course lesson as slides

Lessons today are `title` + a long `content` paragraph (about 80 words) + optional `keyTakeaways`. The slide format can be **built from existing content**, so no regeneration is needed for launch:

| Slide | Built from | Layout |
|---|---|---|
| 1 · Hook | Topic cover art + lesson title | Full art, title, "Lesson 1 of 3" |
| 2–4 · Ideas | `content` split into sentences, 1–2 sentences per slide (or `keyTakeaways` when present) | Large headline + 1–3 lines on a lilac card, with a small topic icon (no per-slide art) |
| 5 · Try it | Last sentence reframed as an action, or a fixed prompt ("When will you try this today?") | One question with 3 quick chips or a one-line answer |
| After the last lesson | Existing quiz | Unchanged, restyled |
| Done | XP and coins earned | Celebration art + "+100 XP" + streak |

UI: segmented progress bar at the top, swipe or Next / Back buttons, a "Read full lesson" link that opens the original paragraph, and the Questor FAB offering "Explain this".

**Phase 2b (backend):** update the generator (`global_daily_courses` JSON) to output a `slides` array per lesson (`headline`, `body` ≤ 180 chars, `illustration_key`, optional `question`). The app prefers `slides` when present and falls back to the split above. Later, a slide can carry `video_url` for 30–60 s clips without changing navigation.

---

## 7. Phases, with done criteria

**Phase 0 — assets (you, in parallel):** generate the 11 images in the prompt pack (8 topic covers + 3 goal covers). Phase 1 can start without them using gradient placeholders.

**Phase 1 — foundation + Home**
- New tokens in `AppColors` and the theme. Magenta and bright gold removed.
- Components from §3 built and used on Home.
- Home in the new order, with Today's Quest working.
- 5-tab nav. Profile reachable from the avatar.
- Done when: Home first screen answers "what do I do now?" at 360×740 without scrolling, with no layout overflow at 320 dp.

**Phase 2 — core journey**
- Goals, Mini Courses list, lesson slides (client-side split), Challenges, Wallet.
- Done when: every screen uses `MlqHeroHeader` and the button set, and no screen shows more than one gold CTA per card.

**Phase 3 — community**
- Victory Wall composer and achievement cards, Ranks with the pinned own row and My School tab, Questor quick starts.

**Phase 4 — value-added**
- Library Explore and My School on the light theme, featured rotation, and category art.
- Generator outputs `slides` (Phase 2b), if not done earlier.

---

## 8. Guardrails

- The guide and mockups are references. Where they disagree with real data, real data wins.
- No rendered text inside illustrations. All copy is live text, so it can be translated, stays sharp and can be edited.
- Illustrations are WebP, under 250 KB for cards and under 450 KB for headers. The app is already large, and some existing badge PNGs are 2 MB.
- Test at 320, 360 and 412 dp widths, and with text scale at 1.3.
- Keep the premium and entitlement gates, the web wallet hiding and the school gating exactly as they are today.

---

## 9. Open questions for the product owner

1. Confirm the 5-tab nav, with Profile moving to the Home avatar.
2. Confirm the lean art scope (11 images) or name any screen where you want custom art.
3. Should Faith & Values be a future Library category? If yes, it needs content before it gets a tile.
4. Is Questor's coin cost per message still active?
