# Consistency v2 — Design tokens (handoff for Phase 1)

Seed: `#2CA8CB` (= `AppColors.primaryColor`). Font: Work Sans 300/400/500/700 (already bundled as WorkSans; drop the 100 weight — illegible on dark).

| token | light | dark | Dart target |
|---|---|---|---|
| primary (seed) | `#2CA8CB` | `#2CA8CB` | `ColorScheme.fromSeed(seedColor: AppColors.primaryColor)` then override `primary` |
| onPrimary | `#FFFFFF` | `#FFFFFF` | `colorScheme.onPrimary` |
| surface (scaffold) | `#E8EEF2` | `#39393A` | `scaffoldBackgroundColor` / `colorScheme.surface` |
| surfaceContainer (cards) | `#F6F8FA` | `#434345` | `cardColor` / `colorScheme.surfaceContainer` |
| surfaceContainerLow (inset, inactive track, nav) | `#DCE4EA` | `#2E2E30` | `colorScheme.surfaceContainerLow`, `NavigationBarTheme.backgroundColor` |
| outline (card border 2px) | `#2CA8CB` | `#2CA8CB` | `colorScheme.outline` (identity: primary border stays) |
| divider | `#B9C6CF` | `#5A5A5C` | `dividerColor` |
| text primary | `#26282B` | `#F2F5F7` | `colorScheme.onSurface` |
| text secondary | `#5C646B` | `#B4BAC0` | `colorScheme.onSurfaceVariant` |
| danger | `#CB2E33` | `#CB2E33` | `colorScheme.error` |
| success | `#418F3F` | `#418F3F` | `ThemeExtension.success` |
| day quality q0 (no data) | `#C4CFD6` | `#55585B` | `ThemeExtension.quality[0]` |
| q1 (< 25 %) | `#CB2E33` | same | `quality[1]` |
| q2 (25–49 %) | `#E0862E` | same | `quality[2]` |
| q3 (50–74 %) | `#2CA8CB` | same | `quality[3]` |
| q4 (≥ 75 %) | `#418F3F` | same | `quality[4]` — replaces `Utilities.activeColor` |
| radius card / pill / button | 28 / 999 / 16 | | `RoundedRectangleBorder` |
| type hero / title / heading / body / caption | 64·700 / 32·700 / 24·500 / 16·500 / 12·400 | | `ThemeExtension<AppText>` |

Rule: `activeColor(value)` → `q1` if <25, `q2` if <50, `q3` if <75, `q4` otherwise; `q0` when no data. Threshold line (setting) draws as `primary`.

## Streak flame tiers (icon `local_fire_department`)
| tier | days | color | icon | motion |
|---|---|---|---|---|
| 0 | 0 | `--f0` #8A9299 (text-2 tone) | outline | none |
| 1 | 1–6 | `--f1` #E0862E | filled | none |
| 2 | 7–29 | `--f2` #E85D2A | filled | subtle flicker (opacity 0.85↔1, 1.2s) |
| 3 | 30–99 | `--f3` #CB2E33 | filled + soft glow | flicker |
| 4 | 100+ | `--f4` #2CA8CB (blue flame) | filled + glow | flicker + slow pulse (scale 1↔1.08, 2s) |
| milestone 7 / 30 / 100 / 365 | — | tier color | — | one-shot celebration on save (scale burst + ring sweep, ≤800 ms) |

Dart: `ThemeExtension<StreakTiers>` with `List<Color> flame` and `tierFor(int days)`. Motion via `AnimationController.repeat(reverse: true)`, gated by `MediaQuery.disableAnimations`.

## Streak flame tiers (icon `local_fire_department`)
| tier | days | color | icon | motion |
|---|---|---|---|---|
| 0 | 0 | `--f0` #8A9299 (text-2 tone) | outline | none |
| 1 | 1–6 | `--f1` #E0862E | filled | none |
| 2 | 7–29 | `--f2` #E85D2A | filled | subtle flicker (opacity 0.85↔1, 1.2s) |
| 3 | 30–99 | `--f3` #CB2E33 | filled + soft glow | flicker |
| 4 | 100+ | `--f4` #2CA8CB (blue flame) | filled + glow | flicker + slow pulse (scale 1↔1.08, 2s) |
| milestone 7 / 30 / 100 / 365 | — | tier color | — | one-shot celebration on save (scale burst + ring sweep, ≤800 ms) |

Dart: implemented as `AppTokens.flame` + `AppTokens.flameTier(days)` (lib/configs/app_tokens.dart). Motion via `AnimationController.repeat(reverse: true)`, gated by `MediaQuery.disableAnimations`.

Source of truth: Claude Design project b473eda8-1101-4699-a494-6390baa9a37e (tokens.md / tokens.css). Approved 2026-08-16.
