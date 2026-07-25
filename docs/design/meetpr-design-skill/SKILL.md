---
name: meetpr-design
description: Use this skill to generate well-branded interfaces and assets for MeetPR (力量举训练 App，黑金硬核风格，暗/亮双主题), either for production or throwaway prototypes/mocks/etc. Contains essential design guidelines, colors, type, fonts, assets, and UI kit components for prototyping.
user-invocable: true
---

Read the README.md file within this skill, and explore the other available files.
If creating visual artifacts (slides, mocks, throwaway prototypes, etc), copy assets out and create static HTML files for the user to view. If working on production code, you can copy assets and read the rules here to become an expert in designing with this brand.
If the user invokes this skill without any other guidance, ask them what they want to build or design, ask some questions, and act as an expert designer who outputs HTML artifacts _or_ production code, depending on the need.

Folder map: `tokens/` CSS custom properties (import via `styles.css`); `guidelines/` visual-spec cards (open in browser); `components/core/` React primitives with .d.ts contracts and .prompt.md usage notes; `reference/` the full interactive app mockups these rules were extracted from — student app (学员端 dark/light/双主题) and coach app (教练端 dark/light), all restyled to this system (open any .dc.html in a browser — needs sibling support.js).

Key facts: dark is the default theme (`:root`), light mode scopes `.theme-light`; primary CTA is solid gold #FFB800 with black ink on dark, deep blue-black #111827 with white text on light; type = Archivo (display) + IBM Plex Mono (data) + IBM Plex Sans/Noto Sans SC (body); radius scale 10/12/16/20/999; icons are Lucide-style 2.2px stroke inline SVG; no emoji.
