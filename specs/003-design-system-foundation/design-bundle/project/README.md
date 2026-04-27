# MeetPR Design System

> iOS-native powerlifting training platform for serious coaches and their students.

## Product context

**MeetPR** is an iPhone-native app for the powerlifting community (squat / bench / deadlift — "SBD"). It is built for two distinct user roles:

- **Coaches** build periodized training cycles — 1-week and 4-week mesocycles with progression rules — and review their athletes' work.
- **Students** (athletes) log every set (weight × reps × RPE), upload form videos for per-set coach review, and follow the program their coach has assigned.

The product is opinionated and serious. It is not a general-purpose fitness app, not a wellness app, not a gamified habit tracker. Its visual and verbal voice should sit comfortably alongside SBD Apparel, Juggernaut Training Systems, MASS Research, and Stronger By Science — brands that respect the technical reader.

### Sources

This system was authored from a written brief only — no Figma file or codebase was attached at the time of creation. If you have access to:

- The MeetPR marketing site (the brand's established voice / visual language)
- The iOS app codebase
- A Figma library

…please re-attach them and ask for a refresh. The visual DNA references called out in the brief were:

- **SBD Apparel** — pure black + saturated red, athletic authority
- **Juggernaut / MASS / Stronger By Science** — serious technical typography
- **Druk / Acumin display + monospace section headers** — industrial / lab-equipment aesthetic
- **Apple Pro launch language** (iPhone Pro / Mac Pro keynote) — confident, cinematic, dark-on-dark, single accent

---

## Index

Top-level files:

- `README.md` — this file
- `SKILL.md` — entry point when this folder is loaded as a Claude Skill
- `colors_and_type.css` — all design tokens (colors, type, spacing, radii) as CSS custom properties

Folders:

- `fonts/` — webfonts (none required; system uses iOS-native SF Pro / SF Mono)
- `assets/` — logos, marks, generic imagery
- `preview/` — Design System tab preview cards (one HTML file per concept)
- `ui_kits/ios_app/` — the MeetPR iOS UI kit: components and 5 hi-fi composed screens

(The CONTENT FUNDAMENTALS, VISUAL FOUNDATIONS, and ICONOGRAPHY sections live below.)

---

## CONTENT FUNDAMENTALS

The MeetPR voice is **confident, terse, and technical**. We talk to athletes and coaches who already know what RPE means, what a backoff set is, and what a 1RM is. We do not over-explain. We do not cheerlead.

### Tone

- **Direct.** Statements over questions. "RPE 10 reached. Reduce W4 backoff +5%?" — not "Hey, looks like you're pushing hard! Want to dial it back?"
- **Technical.** Use the real terminology. RPE, e1RM, mesocycle, AMRAP, top set, backoff. We do not soften jargon for accessibility.
- **Lab-coat objective.** State the numbers. The numbers are the story.
- **Never cute.** No "Yay!", no "Let's crush it", no "💪", no "You got this!".

### Casing

- **Body copy:** sentence case. "Squat W3D1 published."
- **Eyebrow / technical labels:** ALL CAPS in monospace, often with a colon, slash, or trailing rule. `PROTOCOL 01:`, `AI_SUGGESTION //`, `SQUAT STANDARD ────`
- **Buttons:** Title Case for primary CTAs ("Save Mesocycle"), sentence case for secondary ("Discard changes").
- **Section headers in app:** Title Case, bold display weight.
- **Numbers:** never spelled out. `4 weeks`, not "four weeks". Always with a unit when relevant: `200 KG`, `94%`, `RPE 9.5`, `+15 KG`.

### Person

- **You / your** addressing the user. "Your W3 max attempt is queued."
- **First-person plural ("we") is rare** — only in marketing/onboarding when speaking as the product team.
- The AI assistant speaks as **a system, not a personality.** It says "Detected RPE 10 across 3 sessions." not "I noticed you've been working super hard!"

### Emoji

- **Never.** Not in the app, not in marketing, not in copy. The brand reads as professional gym equipment, not consumer software. The closest we get to a "decorative" character is a monospace bullet `•`, an em dash `—`, a slash `//`, or a horizontal rule `────`.

### Examples

| Context | ✓ MeetPR voice | ✗ Wrong voice |
| --- | --- | --- |
| Plan published | `Squat W3D1 published. Notify Chen Lei?` | `Yay! Your squat plan is ready 🎉 Want to send it?` |
| AI suggestion | `RPE 10 reached. Reduce W4 backoff +5%?` | `Hey, looks like you're working hard! Maybe take it easier?` |
| Empty state | `No sessions logged this week.` | `Looks like you haven't trained yet — let's get started!` |
| PR detected | `NEW PR — 200 KG ×1 @ RPE 9.5` | `Congrats! 🏆 You hit a new personal best!` |
| Error | `Upload failed. Tap to retry.` | `Oops! Something went wrong, please try again.` |
| Loading | `Computing 1RM projections…` | `Just a sec, working on it!` |

### Microcopy patterns

- **Status as a sentence fragment:** `2 athletes overdue`, `Synced 3m ago`, `Uploading 67% // 12.4 MB / 18.5 MB`
- **Eyebrow + headline:** `PROTOCOL 01:` + `THE KINETIC MONOLITH`. The eyebrow is the system label; the headline is the human-readable title.
- **Numerical hero blocks:** small mono red label + huge tabular numeral + small unit. `SQUAT STANDARD` / `320` / `KG`.

---

## VISUAL FOUNDATIONS

### Color

- **95% of pixels are black, white, or a neutral gray.** The interface is dark-first; light mode is a fallback that must work but is not where most users live.
- **One brand red** (`#E5221E`) is the SIGNAL. It is used sparingly — for PR badges, AI moments, eyebrow labels, the active-tab underline, and danger states. **A single screen should rarely have more than 2–3 red marks.** Red doubles as the danger color; we don't need a separate alert red.
- **Two semantic accents** beyond red: a saturated green (`#1FB358`) for "low fatigue" / "+15 KG this block" / completion deltas, and an amber (`#E0A810`) used very rarely for overreaching warnings (RPE 9–10 sustained).
- We **never** use pastels, gradients, purples, teals, or "wellness" pinks. Backgrounds are flat.

### Backgrounds

- **Flat solid black** (`#000000`) in dark mode; flat near-white (`#FAFAFA`) in light mode.
- Surfaces are layered by raising the value 1–2 steps: `#0E0E0E` → `#161616`. We **do not** use shadows to express elevation in dark mode (shadows on black are invisible). We use subtle 1px borders (`#262626`) instead.
- **No imagery wallpapers, no patterns, no gradients, no grain.** The only "image" content is athlete-uploaded form video.

### Typography

- **iOS system fonts only.** SF Pro (NOT SF Pro Rounded — rounded reads too friendly), SF Mono for technical labels, PingFang SC for Chinese.
- **Display numerals** are SF Pro Heavy, tabular `.monospacedDigit()` variant — when we show `200 KG` we want the digits in a fixed grid so they don't dance as the number changes.
- **Mono labels are tracked** (+0.5 to +0.8 letter-spacing) and ALL CAPS — `PROTOCOL 01:`, `AI_SUGGESTION //`. They feel like printed lab-equipment readouts.
- We **avoid thin/elegant weights** (200/300). Display type is Bold or Heavy; body is Regular or Semibold.

### Spacing

- 8pt grid. Tokens: `4 / 8 / 12 / 16 / 24 / 32 / 48 / 64`.
- Vertical rhythm: 32pt above section titles, 16pt below; cards 16pt internal padding; list rows 12pt vertical inset.
- **Density is medium-tight.** This is a working tool, not a marketing page — we do not give every component room to breathe.

### Borders, radii, shadows

- **Radius scale:** 4 (chips) / 8 (inputs) / 12 (cards) / 16 (modals) / 999 (pills).
- **Borders:** 1px hairlines using `#262626` (dark) or `#E5E5E5` (light). Borders are how we separate surfaces, not shadows.
- **Shadows:** essentially absent in dark mode. In light mode we permit a single soft shadow tier on modals (`0 8px 24px rgba(0,0,0,0.08)`), but cards stay flat.

### Motion

- **200–280ms** durations. Curve: `cubic-bezier(0.32, 0.72, 0, 1)` (Apple's iOS standard ease).
- **Never spring/bounce.** Springs feel playful — wrong tone.
- Animations are **opacity + small translation only.** No scale-from-0, no whoosh, no parallax. A modal slides up 16pt and fades in. A list row's done-indicator fades on.
- **Haptics carry the "feel"** that animations don't: light tick on every set checkbox, medium impact on PR detection, success pattern on session complete.

### States

- **Hover (iPad / external pointer):** background lifts one surface step (`#0E0E0E` → `#161616`). Never a color shift.
- **Pressed:** opacity 0.6, no scale. We do not shrink on press — that reads consumer-app.
- **Focus:** 2px outline in white (dark) / black (light). Inputs swap their border to white/black.
- **Disabled:** opacity 0.35.
- **Loading:** a single brand-red 1px indeterminate bar at the top of the view. **No spinning circles, ever.**

### Transparency & blur

- Used only in two places: the iOS native nav bar (system blur, we don't fight it), and the bottom of the keyboard area when the in-app numeric keyboard is presenting.
- Cards, modals, and overlays are **opaque**. We don't do glassmorphism.

### Layout

- iPhone-first. Safe-area aware. The tab bar is fixed; content scrolls beneath the nav bar's blur.
- **Numbers are right-aligned and tabular.** Set rows, history charts, weight columns — always.
- Lists use a 56pt minimum row height; tap targets ≥ 44pt.
- The active tab gets a 2px **brand-red** underline; inactive tabs are gray text only.

### Imagery

- The only first-party imagery is the wordmark and a small set of geometric marks. We do not use photography in the app chrome.
- User-generated form video plays in flat black-letterboxed players with a thin red scrub bar — same visual language as the rest of the system.

---

## ICONOGRAPHY

MeetPR uses **Apple SF Symbols** as the primary icon system. SF Symbols ships with iOS, ligates with SF Pro at every weight, and is the unambiguous correct choice for an iPhone-native app. We use the **Regular** weight for tab bars and inline icons; **Semibold** weight when an icon sits next to bold display numerals; **Medium** as default.

For this design system (which lives in HTML for preview), we substitute SF Symbols with **Lucide** (`lucide.dev`) — a stroke-based open-source set with similar weight, geometry, and proportion. This is a **flagged substitution**: when implementing in iOS, swap each Lucide name for the corresponding SF Symbol. A mapping table lives in `assets/icons/MAPPING.md`.

### Rules

- **Icons are monochrome.** Single color — almost always a text color (`fg-primary` / `fg-secondary`). The brand red is reserved; an icon is rarely red on its own. Exception: the `record` / `live` dot in the active-recording state.
- **Stroke-based, 1.5–2px equivalent weight.** SF Symbols Regular maps to ~1.75px Lucide.
- **24×24 default render size**, 20×20 in dense list rows, 32×32 in empty states.
- **No emoji, ever** — `💪`, `🏋️`, `🔥` are explicitly forbidden, in app and marketing alike.
- **No unicode-as-icon abuse.** We do permit a few typographic signals as part of the type system (em dashes, bullets, slashes, horizontal rules) — those are lockup ornaments, not icons.
- **No custom illustrations of gym equipment.** No cartoon barbells, no skeuomorphic plates. If a screen feels empty, the answer is composition, not decoration.

### Logo & marks

- `assets/logo/meetpr-wordmark.svg` — primary wordmark, used in onboarding splash and marketing
- `assets/logo/meetpr-mark.svg` — square monogram for app icon and small lockups
- Both are designed to render correctly on `#000000` and `#FFFFFF`. There is no two-color or gradient version.
