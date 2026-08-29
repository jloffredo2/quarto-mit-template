-- Beamer support for the template's navigation conventions:
--  * [text](#id){.button}  ->  \hyperref[id]{\beamergotobutton{text}}
--  * the `# Appendix {#appendix}` divider triggers \appendix
--    (appendixnumberbeamer: resets numbering to A-1, A-2, ...)

local function is_beamer()
  return FORMAT:match("beamer") ~= nil or FORMAT:match("latex") ~= nil
end

-- Render inline code as plain \texttt so slides with inline code (e.g. an
-- email on a standout slide) aren't marked [fragile] — metropolis's standout
-- frames error on the fragile option. Code *blocks* are unaffected.
function Code(el)
  if is_beamer() then
    local s = el.text
      :gsub("\\", "\0")
      :gsub("([%%$#&_{}])", "\\%1")
      :gsub("~", "\\textasciitilde{}")
      :gsub("%^", "\\textasciicircum{}")
      :gsub("%z", "\\textbackslash{}")
    return pandoc.RawInline("latex", "\\texttt{" .. s .. "}")
  end
end

-- [text]{.alert} -> \alert{text} (pandoc only maps .alert divs, not spans)
function Span(el)
  if is_beamer() and el.classes:includes("alert") then
    local inlines = pandoc.Inlines({ pandoc.RawInline("latex", "\\alert{") })
    inlines:extend(el.content)
    inlines:insert(pandoc.RawInline("latex", "}"))
    return inlines
  end
end

function Link(el)
  if is_beamer() and el.classes:includes("button") and el.target:sub(1, 1) == "#" then
    local label = el.target:sub(2)
    local text = pandoc.utils.stringify(el.content)
    return pandoc.RawInline("latex",
      "\\hyperref[" .. label .. "]{\\beamergotobutton{" .. text .. "}}")
  end
end

function Header(el)
  if not is_beamer() then
    return nil
  end
  -- metropolis standout frames are titleless (the big centered text is the
  -- content); move the header text into the frame body, styled like a title
  if el.level == 2 and el.classes:includes("standout") then
    local inlines = pandoc.Inlines({ pandoc.RawInline("latex", "{\\usebeamerfont{title}") })
    inlines:extend(el.content)
    inlines:insert(pandoc.RawInline("latex", "\\par}\\vspace{0.3em}"))
    local title_para = pandoc.Para(inlines)
    el.content = pandoc.Inlines({})
    return { el, title_para }
  end
  if el.level == 1 and
      (el.identifier == "appendix" or el.classes:includes("appendix")) then
    -- \appendix must run between frames, but pandoc wraps loose blocks into
    -- frames. So: set a global flag from inside the preceding frame; the
    -- \AtBeginSection hook in beamer-header.tex (which runs at top level)
    -- sees it and fires the real \appendix before the section page.
    return { pandoc.RawBlock("latex", "\\global\\mitappendixpendingtrue"), el }
  end
end

-- append raw latex to header-includes
local function add_header(meta, raw, format)
  local hi = meta["header-includes"]
  if hi == nil then
    hi = pandoc.MetaList({})
  elseif hi.t ~= "MetaList" then
    hi = pandoc.MetaList({ hi })
  end
  hi:insert(pandoc.MetaBlocks({ pandoc.RawBlock(format or "latex", raw) }))
  meta["header-includes"] = hi
end

local function to_latex(inlines)
  return (pandoc.write(pandoc.Pandoc({ pandoc.Plain(inlines) }), "latex"):gsub("%s+$", ""))
end

-- Per-author affiliations on the beamer title page. Quarto keeps the parsed
-- authors in `by-author` (name + affiliations), but pandoc's \author only gets
-- the names, so affiliations show up in HTML and silently vanish from the PDF.
-- Rebuilding meta.author doesn't stick (quarto reassembles it after this filter)
-- and header-includes lands before \author, so redefine it at \begin{document},
-- which still runs before the title frame.
local function authors_with_affiliations(meta)
  local by = meta["by-author"]
  if by == nil then
    return
  end

  local parts = {}
  local any = false
  for _, a in ipairs(by) do
    if a.name == nil then
      return -- unexpected shape; leave pandoc's \author alone
    end
    local latex = to_latex(pandoc.Inlines(a.name.literal or a.name))

    local affs = {}
    for _, aff in ipairs(a.affiliations or {}) do
      if aff.name ~= nil then
        affs[#affs + 1] = pandoc.utils.stringify(aff.name)
      end
    end

    if #affs > 0 then
      any = true
      -- each author is its own top-aligned box, else the \\ inside an \and
      -- column staggers the names and affiliations onto mismatched lines
      latex = "\\begin{tabular}[t]{@{}l@{}}" .. latex ..
          "\\\\{\\footnotesize\\color{MITFooterGray}" ..
          to_latex(pandoc.Inlines({ pandoc.Str(table.concat(affs, ", ")) })) ..
          "}\\end{tabular}"
    end
    parts[#parts + 1] = latex
  end

  if any then
    add_header(meta, "\\AtBeginDocument{\\author{" ..
      table.concat(parts, " \\and ") .. "}}")
  end
end

-- `footer:` in the document YAML drives the beamer footline too (revealjs uses
-- the key natively). Emitted as provide+renew so it wins regardless of whether
-- it lands before or after beamer-header.tex's \providecommand fallback.
local function footer_command(meta)
  if meta.footer == nil then
    return
  end

  local footer = meta.footer
  local inlines
  if type(footer) == "string" then
    inlines = pandoc.Inlines({ pandoc.Str(footer) })
  elseif footer.t == "MetaBlocks" then
    inlines = pandoc.utils.blocks_to_inlines(footer)
  else
    inlines = pandoc.Inlines(footer)
  end

  -- run it through the latex writer so markup and special characters are handled
  add_header(meta, "\\providecommand{\\mitfootertext}{}%\n" ..
    "\\renewcommand{\\mitfootertext}{" .. to_latex(inlines) .. "}")
end

-- `mit-logo: false` drops the MIT lockup from the title slide (useful when the
-- deck is coauthored across institutions). Defaults to showing it.
local function logo_toggle(meta)
  local v = meta["mit-logo"]
  if v == nil then
    return
  end
  local show = v
  if type(v) ~= "boolean" then
    show = pandoc.utils.stringify(v) ~= "false"
  end
  if show then
    return
  end

  if is_beamer() then
    -- lands after beamer-header.tex's \titlegraphic, so this wins
    add_header(meta, "\\titlegraphic{}")
  else
    add_header(meta,
      "<style>.reveal .slides section#title-slide { background-image: none !important; }</style>",
      "html")
  end
end

function Meta(meta)
  logo_toggle(meta)
  if not is_beamer() then
    return meta
  end
  footer_command(meta)
  authors_with_affiliations(meta)
  return meta
end
