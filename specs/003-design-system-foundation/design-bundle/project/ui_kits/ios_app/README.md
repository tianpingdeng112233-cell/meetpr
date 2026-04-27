# MeetPR iOS UI Kit

Five hi-fi composed screens that demonstrate the design system in context.

## Files

- `index.html` — canvas presenting all 5 screens in iPhone frames
- `screens.css` — shared screen-level styles (navbar, tabbar, card, badge)
- `components.jsx` — shared atoms: `Icon`, `StatusBar`, `TabBar`, `Eyebrow`, `LoadingBar` + tab definitions
- `screens-1.jsx` — `CoachDashboard`, `PlanningEditor`
- `screens-2.jsx` — `StudentTrainingDay`, `StudentPlanView`, `AuthFlow`
- `ios-frame.jsx`, `design-canvas.jsx` — starter components (available if you want to swap the lightweight phone bezel for the full-fidelity iOS frame, or the static grid for a pan/zoom canvas)

## Screens

1. **Auth** — phone entry → role selection (athlete / coach)
2. **Coach Dashboard** — Today's schedule, AI alert card, roster status
3. **Planning Editor** — 4-week mesocycle excel-style preview, exercise detail
4. **Student Training Day** — active set hero, RPE slider, set list, coach note
5. **Student Plan View** — week progress, day calendar, e1RM history chart

## Notes

- Icons are inlined Lucide-style stroked SVGs. In iOS production, swap for SF Symbols (see `assets/icons/MAPPING.md`).
- The phone frame in `index.html` is intentionally minimal — for full-fidelity iOS chrome, wrap each screen in `<IOSFrame>` from `ios-frame.jsx`.
