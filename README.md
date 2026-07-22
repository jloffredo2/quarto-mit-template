# MIT Reveal.js Presentation Template

Personal Quarto presentation template matching [joseph-loffredo.com](https://joseph-loffredo.com): white slides, MIT maroon (`#750014`) title bars, Roboto Serif headings, Neue Haas Grotesk body text, MIT logo bottom center, `n/N` slide numbers.

## Starting a new talk

Copy `template.qmd` and the `_extensions/` folder into a new directory, or (once this repo is on GitHub):

```bash
quarto use template jloffredo2/quarto-template
```

Minimal front matter:

```yaml
---
title: "My Talk"
author: "Joseph R. Loffredo"
institute: "Massachusetts Institute of Technology"
date: today
format: mit-revealjs
---
```

Render with `quarto render talk.qmd` or live-preview with `quarto preview talk.qmd`.

## Features

- `## Slide Title` — content slide with the maroon header bar
- `## Slide Title {.plain}` — no bar (maroon title text on white); good for full-bleed figures
- `# Section Name` — maroon section divider slide
- Footer: name/institution lower left, MIT logo bottom center, slide number lower right (all hidden on the title slide)

## Appendix navigation (beamer gotobutton workflow)

Give slides IDs and link to them with `.button` pills:

```markdown
## Main Results {#main-results}

[Estimates](#app-estimates){.button}

# Appendix {#appendix}

## Full Estimates {#app-estimates}

[Return](#main-results){.button} [Appendix TOC](#appendix-toc){.button}
```

The slide starting the appendix must have id `appendix` (or class `.appendix`). Everything from there on is numbered `A-1, A-2, …` and excluded from the main `n/N` count — the `appendixnumberbeamer` behavior.

## Offline presenting / PDF backup

Fonts load from Adobe Fonts (Neue Haas Grotesk, kit `use.typekit.net/nck6fpm.css` — same kit as the website) and Google Fonts (Roboto Serif), so a plain render needs internet. Two escape hatches:

1. **Self-contained HTML** (fonts baked in — render while online, present anywhere):

   ```bash
   quarto render talk.qmd -M embed-resources:true
   ```

   If the deck has math, MathJax still loads from a CDN. For a fully offline file, switch math to the browser-native renderer (verified: zero external requests):

   ```bash
   quarto render talk.qmd -M embed-resources:true -M html-math-method:mathml
   ```

2. **PDF backup** of the exact same deck: open the rendered HTML in Chrome with `?print-pdf` appended to the URL, then Cmd+P → Save as PDF. Or headless:

   ```bash
   quarto render talk.qmd
   "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
     --headless --print-to-pdf=talk.pdf --no-pdf-header-footer \
     "file://$(pwd)/talk.html?print-pdf"
   ```

If Neue Haas Grotesk ever fails to load (offline, or a domain not allowed on the Adobe Fonts kit), the deck falls back to Helvetica Neue, which is close. To allow a new domain, edit the web project at fonts.adobe.com.
