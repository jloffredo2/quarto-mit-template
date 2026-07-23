# MIT Presentation Template (Quarto)

Personal Quarto presentation template matching [joseph-loffredo.com](https://joseph-loffredo.com): white slides, MIT maroon (`#750014`), Roboto Serif headings, Neue Haas Grotesk body text. One `.qmd` renders to both formats:

```bash
quarto render talk.qmd                  # revealjs (HTML) — default
quarto render talk.qmd --to mit-beamer  # beamer (PDF, metropolis-based)
```

## Starting a new talk

Copy `template.qmd` and the `_extensions/` folder into a new directory, or (once this repo is on GitHub):

```bash
quarto use template jloffredo2/quarto-template
```

Minimal front matter:

```yaml
---
title: "My Talk"
subtitle: "Venue or Paper Title"
author: "Joseph R. Loffredo"
date: today
format:
  mit-revealjs: default
  mit-beamer: default
---
```

## Slide types

| Syntax | Result |
|---|---|
| `## Title` | content slide: maroon Roboto Serif title (HTML), maroon title bar (PDF) |
| `## Title {.plain}` | beamer's native `plain` frame (no footline); no effect in HTML |
| `# Section` | metropolis section page: left title over a maroon/gray rule |
| `## Thank You! {.standout}` | full-maroon closing slide, centered white serif title |
| `# Appendix {#appendix}` | starts the appendix: slides after it are numbered A-1, A-2, … |

Footer on every content slide: **Joseph R. Loffredo, MIT** lower left (black), page number lower right (maroon). The title slide, section pages, and standout slides have no footer. Main slides show `n/N` where `N` excludes the title, section pages, standout slides, and the appendix (`appendixnumberbeamer` behavior, replicated in revealjs by `mit-nav.html`).

## Appendix navigation (beamer gotobutton workflow)

Give slides IDs and link with `.button` pills — in HTML they're styled like `\beamergotobutton`; in the PDF they *are* `\beamergotobutton`s (via `mit-filters.lua`):

```markdown
## Main Results {#main-results}

[Estimates](#app-estimates){.button}

# Appendix {#appendix}

## Backup Slides {#appendix-toc}

## Full Estimates {#app-estimates}

[Return](#main-results){.button} [Appendix TOC](#appendix-toc){.button}
```

The appendix divider must have id `appendix` (or class `.appendix`).

## Fonts

- **HTML**: loaded from Adobe Fonts (`use.typekit.net/nck6fpm.css`, same kit as the website) and Google Fonts. Needs internet; falls back to Helvetica Neue / Georgia offline.
- **PDF**: Roboto Serif is bundled in `_extensions/.../assets/fonts/` (OFL license) — renders identically anywhere. Body uses Neue Haas Grotesk Text Pro if installed as a system font, else Helvetica Neue.

## Offline presenting / PDF backup of the HTML deck

```bash
# single self-contained HTML file, zero external requests (fonts + math embedded)
quarto render talk.qmd -M embed-resources:true -M html-math-method:mathml

# PDF snapshot of the revealjs deck
quarto render talk.qmd
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless --print-to-pdf=talk.pdf --no-pdf-header-footer \
  "file://$(pwd)/talk.html?print-pdf"
```

Or just use the beamer PDF as the backup.

## Extension layout

```
_extensions/jloffredo2/mit/
├── _extension.yml     # the two formats and their defaults
├── mit.scss           # revealjs theme
├── mit-nav.html       # revealjs: beamer-style numbering + chrome hiding
├── fonts.html         # revealjs: Adobe/Google Fonts links
├── beamer-header.tex  # beamer: fonts, colors, footline, appendix numbering
├── mit-filters.lua    # beamer: gotobuttons, \appendix, standout titles
└── assets/            # logos, Roboto Serif TTFs
```
