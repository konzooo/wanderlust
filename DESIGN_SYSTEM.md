# Wanderlust — Design System

The design itself is unchanged — this documents it as a proper, named system instead of scattered raw values, and closes the small inconsistencies found along the way. See [VISION.md](VISION.md) for the brand rationale.

Source of truth lives in `Packages/DesignSystem/Sources/DesignSystem/`: `Colors.swift`, `Typography.swift`, `Radius.swift`, `Fonts.swift`, `Spacing.swift`.

---

## Typography

Family: **Kanit**. Raw weight helpers (`.kanit()`, `.kanitLight()`, `.kanitMedium()`, `.kanitBold()`, `.kanitItalic()`, etc.) still exist in `Fonts.swift` for one-off text — but anything matching one of the roles below should use the named token from `DS.Typography` instead.

| Token | Spec | Role |
|---|---|---|
| `DS.Typography.displayRegular` | 34 / Regular | Screen page title ("Next Trip", "What's your style?") |
| `DS.Typography.displayMedium` | 34 / Medium | Hero title over a photo (Output header) |
| `DS.Typography.displayLight` | 34 / Light | Soft empty-state heading |
| `DS.Typography.displayBold` | 34 / Bold | Saved Trip card title |
| `DS.Typography.sheetTitle` | 22 / Italic | Modal / sheet title |
| `DS.Typography.subtitle` | 18 / Light | Page subtitle, under a Display title |
| `DS.Typography.fieldCaption` | 18 / Light | Label above a sheet form field — same size as `subtitle` today, kept as a separate token since the two may diverge later |
| `DS.Typography.fieldLabel` | 16 / Medium | Field / section label on the Next Trip form |
| `DS.Typography.sectionHeader` | 18 / Medium | Heading above a content section (suggestions carousel, favourites group) |
| `DS.Typography.segmentTitle` | 19 / Medium | Title of one segment of content (a day in the itinerary) |
| `DS.Typography.eyebrow` | 15 / Medium Italic | Small label introducing a block of generated prose ("The case", "The catch") |
| `DS.Typography.contextLabel` | 14 / Italic | Where a favourite came from, shown beside it |
| `DS.Typography.tabLabel` | 14 / Medium | Tab-bar and pill-selector labels |

**Typography is content-type, not hierarchy.** Kanit is the app's voice and renders *chrome* — titles, tab and segment labels, section headings, eyebrows. Anything the **model** generated renders in SF Pro Rounded, so generated prose reads as prose and not as another piece of the app's furniture. A heading written by the model is still model text; it does not get Kanit for being a heading.

| Token | Spec | Role |
|---|---|---|
| `DS.Typography.generatedBody` | 15 / SF Pro Rounded | Model-written prose inside a card |
| `DS.Typography.generatedListItem` | 15.5 / SF Pro Rounded | Model-written prose as a list row (itinerary items, favourites) |
| `DS.Typography.generatedTitle` | 18 / Semibold / SF Pro Rounded | A place name the model chose, used as a card title |

**What changed:** "Display" text was 4 different sizes before (34/32/30/28) — one of them (`TripCard`) wasn't even Kanit, it was the system font. All four now share one size; weight alone signals context, and the font-family bug is fixed as part of the same change. `DS.ContentTabBar` followed neither rule — it rendered its labels in the plain system font — and now uses `tabLabel`.

**What stayed distinct on purpose:** `subtitle` and `fieldCaption` render identically today (18/Light) but are two separate tokens — a page subtitle and a sheet form-field label are different jobs that happen to look the same right now, not the same thing.

Body text (16pt family), captions (12–14pt), and one-off text buttons were left as raw `.kanit*()` calls — they were already reasonably consistent and didn't need a named role yet.

---

## Color

| Token | Hex | Role |
|---|---|---|
| `appTint` | `#586FF2` | Primary brand accent |
| `lightPurple` | `#6B84F6` | Lighter accent variant |
| `darkGray` | `#363636` | Dark text/UI variant |
| `border` | `#2C2C2C` | Border color |
| `textLink` | `#0A84FF` | Link text |
| `buttonText` | `#F5F5F5` | Button label color |
| `infoCardBkg` | `#E1E1E1` | Info card background |
| `popoverBackground` | `#F1EBDF` | Sheet / popover background |
| `gradientTop` / `gradientBottom` | `#E6F2FF` / `#FFF0CC` | Global background gradient |
| `suggestionTintA` | `#D8E3EE` | Alternating suggestion-card fill (odd sections) |
| `suggestionTintB` | `#F1F6FA` | Alternating suggestion-card fill (even sections) |

All color usage across the app now goes through this table — the two suggestion tints and the Home flying-plane icon used to be typed as raw hex, bypassing it.

---

## Corner Radius

| Token | Value | Role |
|---|---|---|
| `CGFloat.Radius.compact` | 8 | Small clipped elements & bordered form fields |
| `CGFloat.Radius.field` | 12 | Text inputs & input-adjacent backgrounds |
| `CGFloat.Radius.control` | 14 | Buttons — deliberately kept isolated from Card sizes |
| `CGFloat.Radius.cardSmall` | 16 | Small content cards (itinerary card, Questionnaire swipe card, secret-tip callout) |
| `CGFloat.Radius.image` | 20 | Full-bleed photo surfaces (Home hero image) |
| `CGFloat.Radius.cardLarge` | 24 | Large content cards (form card, Saved Trip card) |

Down from 9 raw values with no names to 6 named tiers. One 2pt radius (the Questionnaire progress-bar track) was left as a literal — it's sized to that specific 4pt-tall bar, not a general design choice, so it didn't belong in the scale.

---

## Spacing

**Left untouched, by decision.** Two scales still exist side by side — `CGFloat.Spacing` (8/16/24/32/64, base-8) and `CGFloat.Padding` (5/10/15/20/25/30/35/40/50/60, base-5). They're built on genuinely incompatible grids, so consolidating them isn't a simple naming pass like the categories above — it would mean picking one grid and remapping real gap values, with real (if small) risk of compounding layout shifts. Revisit later if it becomes worth the more careful pass.

---

## Components

`PrimaryButtonStyle`, `SecondaryButtonStyle`, `Chip`, `DS.ContentTabBar`, `DS.InformativeCard`, `DS.Toast`, `TopHeader`, `HeartIcon`.

`DS.ContentTabBar` takes `init(selection:tabs:)`: tab visibility is per-mode (a group trip has no personal layer; a tab whose content isn't wired up yet is not passed in), so the bar renders what it is given rather than every case of `OutputTab`. It normalizes a selection that isn't in `tabs`, and stacks the icon above the label so a long title shares the same equal-width column as a short one.

Two small fixes landed alongside the tokens:
- `TopHeader` no longer has a debug `Color.red` sitting behind the hero image.
- `TripCard`'s destination title and chip labels now use Kanit — they were the only place in the app rendering text in the system font.

**Still open, not part of this pass:** `SecondaryButtonStyle` remains unused anywhere live (keep for future use, or drop it — your call), and `HeartIcon`'s favorited color is still a raw `.red` with no token behind it.
