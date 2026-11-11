# MIT Presentation Template (Quarto)

Personal Quarto presentation template matching [joseph-loffredo.com](https://joseph-loffredo.com): white slides, MIT maroon (`#750014`), Roboto Serif headings, Neue Haas Grotesk body text. One `.qmd` renders to both formats:

```bash
quarto render talk.qmd                  # revealjs (HTML) — default
quarto render talk.qmd --to mit-beamer  # beamer (PDF, metropolis-based)
```

## Starting a new talk

Copy `template.qmd` and the `_extensions/` folder into a new directory, or (once this repo is on GitHub):

```bash
quarto use template jloffredo2/quarto-mit-template
```

Minimal front matter:

```yaml
---
title: "My Talk"
subtitle: "Venue or Paper Title"
author: "Joe Loffredo"
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
| `## Title {.plain}` | no title and no footer, in both formats |
| `## {.notitle}` | no title, but the footer and slide number stay |
| `## Title {.tight-text}` | HTML only: smaller type for a slide that carries more text than usual |
| `# Section` | metropolis section page: left title over a maroon/gray rule |
| `## Thank You! {.standout}` | full-maroon closing slide, centered white serif title |
| `# Appendix {#appendix}` | starts the appendix: slides after it are numbered A-1, A-2, … |

Footer on every content slide: **Joe Loffredo (MIT)** lower left, slide number lower right (white bold on a maroon bar). The title slide, section pages, and standout slides have no footer and are not counted. Main slides show `n`; appendix slides show `A-n` (`appendixnumberbeamer` behavior, replicated in revealjs by `mit-nav.html`).

Slide content is top-aligned under the title in both formats.

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

In the PDF, a button whose text starts with `Return` goes back to the *last* step of a slide that builds up, not its first (this needs the two LaTeX passes Quarto already runs). A paragraph made only of buttons is pinned to the bottom of the slide, so button rows sit in the same place on every slide.

## Other useful syntax

- `[text]{.alert}` — MIT-red emphasis in both formats (beamer `\alert`)
- `[Author 2020]{.cite}` — small gray parenthetical citation; `[Author. 2020. "Title." *Journal*]{.ref}` — a full reference, small but in body ink and without parentheses
- `::: {.center}` — a short centred takeaway line
- `. . .` on its own line — pause/fragment in both formats; `::: {.incremental}` for incremental lists
- `. . .` between `::: {.column}` blocks inside `::: {.columns}` — reveals the columns one at a time while keeping them side by side (both formats)
- `::: {.steps}` around one list — its items appear one click at a time, with ordinary list spacing; `::: {.step}` — a block that appears on the next click and stays
- `::: {.stack}` wrapping `::: {.beat}` blocks — successive contents that replace each other on one slide (usually images)
- `::: {.timeline}` wrapping `::: {.beat year="1993" label="Label"}` blocks — a horizontal rail that adds one moment per click (current one maroon, earlier ones gray) and swaps the beat's content in underneath
- `::: {.overlay}` — a maroon-ruled callout box over a washed-back slide; put `. . .` before it to land it on a click, and add `only="2"` to limit it to one step in the PDF
- `::: {.block title="Title"}` — a titled box (beamer `block`)
- `::: {.tight}` around a figure — the figure keeps its natural position so text after it stays next to it (PDF; a lone figure otherwise takes the slide's spare space below it)
- Lone images in the PDF are capped at 70% of the text height so they clear the title and footer; set `height=` on the image to override
- Annotated equations (beamer only): `\eqnmarkbox[MITDarkRed]{tag}{term}` inside math, then `\annotate[yshift=-0.6em]{below,left}{tag}{label}` in a ```` ```{=latex} ```` block. Needs `tlmgr install annotate-equations`. Wrap it in `::: {.content-visible when-format="beamer"}` and give the HTML build an `\underbrace` version under `unless-format="beamer"`
- Beamer-only frame options pass through as classes: `{.shrink}` (fit oversized content), `{.allowframebreaks}` (auto-split long frames), `{.t}`/`{.c}`/`{.b}` (vertical alignment)
- `toc: true` in front matter adds an outline slide after the title in both formats

## Spacing (PDF)

Lists, lead-in lines, and items across a pause all share one gap, and nested lists keep the body type size, so slides look consistent without per-slide fixes. Two raw-LaTeX commands adjust it:

- `\sectiongap` — the larger gap between sections on one slide; put it before each `[**Heading**]{.alert}` after the first
- `\packedlists` — removes the list gaps on a frame that carries more than the default fits

````markdown
```{=latex}
\sectiongap
```
````

## Progress rule

The rule under slide titles that fills as the deck advances is off by default. To turn it on:

```yaml
format:
  mit-revealjs:
    theme: [default, _extensions/mit/mit.scss, progress.scss]  # progress.scss: $mit-title-progress: true;
  mit-beamer:
    themeoptions: [progressbar=frametitle, block=fill]
```

`progress.scss` needs a `/*-- scss:defaults --*/` line above the variable.

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
├── mit-filters.lua    # both: buttons, \appendix, steps, timeline, overlays, blocks
└── assets/            # logos, Roboto Serif TTFs
```
