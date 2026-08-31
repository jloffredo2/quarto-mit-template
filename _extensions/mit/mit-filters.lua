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

-- Wrap a span's content in raw latex.
local function wrap_latex(el, open, close)
  local inlines = pandoc.Inlines({ pandoc.RawInline("latex", open) })
  inlines:extend(el.content)
  inlines:insert(pandoc.RawInline("latex", close))
  return inlines
end

--  [text]{.alert} -> \alert{text} (pandoc only maps .alert divs, not spans)
--  [Fraga 2016]{.cite} -> a small grey parenthetical; the parentheses are
--  supplied here (and by mit.scss in revealjs) so the source stays clean.
function Span(el)
  if not is_beamer() then
    return nil
  end
  if el.classes:includes("alert") then
    return wrap_latex(el, "\\alert{", "}")
  end
  if el.classes:includes("cite") then
    return wrap_latex(el, "{\\footnotesize\\textcolor{gray}{(", ")}}")
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
  -- ## Title {.plain}: pandoc's [plain] only drops the footline, so metropolis
  -- still sets the frametitle and its progress rule. Blank the header to leave
  -- the frame genuinely bare; the text stays as the slide's identifier.
  if el.level == 2 and el.classes:includes("plain") then
    el.content = pandoc.Inlines({})
    return el
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

-- A slide whose body is just an image: centre it in the frame. Pandoc emits a
-- bare paragraph, which sits flush left and top; beamer-header.tex bounds the
-- image's height, and this puts it in the middle of the frame.
local function is_lone_image(blk)
  return blk.t == "Para" and #blk.content == 1 and blk.content[1].t == "Image"
end

local function centred(blk)
  return {
    pandoc.RawBlock("latex", "\\vspace*{\\fill}\\begin{center}"),
    blk,
    pandoc.RawBlock("latex", "\\end{center}\\vspace*{\\fill}"),
  }
end

function Blocks(blocks)
  if not is_beamer() then
    return nil
  end
  local out, changed = pandoc.List(), false
  for _, blk in ipairs(blocks) do
    if is_lone_image(blk) or (blk.t == "Figure" and #blk.caption.long == 0) then
      out:extend(centred(blk))
      changed = true
    else
      out:insert(blk)
    end
  end
  if changed then
    return out
  end
end

-- ::: {.stack} wrapping ::: {.beat} blocks -> successive overlays on ONE
-- slide: \only<n> in beamer, an .r-stack of fragments in revealjs. Use it when
-- a later beat should replace an earlier one in place (e.g. swapping figures)
-- rather than advancing to a new frame.
local function stack_div(el)
  local beats = pandoc.List()
  for _, blk in ipairs(el.content) do
    if blk.t == "Div" and blk.classes:includes("beat") then
      beats:insert(blk)
    end
  end
  if #beats == 0 then
    return nil
  end

  local out = pandoc.List()
  if is_beamer() then
    for i, beat in ipairs(beats) do
      out:insert(pandoc.RawBlock("latex", "\\only<" .. i .. ">{%"))
      out:extend(beat.content)
      out:insert(pandoc.RawBlock("latex", "}"))
    end
    return out
  end

  -- revealjs: stack them, and make every beat after the first a fragment
  for i, beat in ipairs(beats) do
    local classes = i > 1 and { "fragment" } or {}
    out:insert(pandoc.Div(beat.content, pandoc.Attr("", classes)))
  end
  return pandoc.Div(out, pandoc.Attr("", { "r-stack" }))
end

-- ::: {.overlay} ... ::: -> a callout box laid over the whole slide: the frame
-- is washed back and the content is boxed in the middle, keeping whatever
-- markdown formatting it carries. Pair it with `. . .` to land it on a click.
-- pgfinterruptboundingbox keeps the full-page wash from inflating the figure's
-- bounding box, which would otherwise shove the slide's own content around.
--  ::: {.block title="..."} : beamer's block environment, and in revealjs a
--  titled box that mit.scss paints to match \setbeamercolor{block title}.
--  The title is parsed as markdown so it may carry emphasis.
local function block_div(el)
  local title = el.attributes["title"]
  local title_inlines = title
    and pandoc.utils.blocks_to_inlines(pandoc.read(title, "markdown").blocks)
    or pandoc.Inlines({})

  if is_beamer() then
    local open = pandoc.Para(pandoc.Inlines({ pandoc.RawInline("latex", "\\begin{block}{") }))
    open.content:extend(title_inlines)
    open.content:insert(pandoc.RawInline("latex", "}"))
    local blocks = pandoc.List({ open })
    blocks:extend(el.content)
    blocks:insert(pandoc.RawBlock("latex", "\\end{block}"))
    return blocks
  end

  -- revealjs: hoist the attribute into a real element so CSS can style it
  -- (left as an attribute it would only surface as a browser tooltip).
  if title then
    el.attributes["title"] = nil
    el.content:insert(1, pandoc.Div({ pandoc.Plain(title_inlines) },
                                    pandoc.Attr("", { "block-title" })))
  end
  return el
end

function Div(el)
  if el.classes:includes("stack") then
    return stack_div(el)
  end
  if el.classes:includes("block") then
    return block_div(el)
  end
  if not el.classes:includes("overlay") then
    return nil
  end
  if not is_beamer() then
    -- revealjs: wrap the content in a single box. Styling the overlay's
    -- children directly would give a separate box to each block, so an
    -- overlay holding (say) a lead-in line and a list would split in two.
    el.content = pandoc.Blocks({
      pandoc.Div(el.content, pandoc.Attr("", { "overlay-box" })),
    })
    return el
  end
  local open = table.concat({
    "\\begin{tikzpicture}[remember picture,overlay]",
    "\\begin{pgfinterruptboundingbox}",
    -- start below the frametitle so the slide keeps its heading
    "\\fill[white,opacity=0.68] ([yshift=-1.15cm]current page.north west) rectangle (current page.south east);",
    "\\end{pgfinterruptboundingbox}",
    "\\node[draw=MITDarkRed,line width=0.5mm,fill=white,inner sep=12pt,align=center,",
    "      text width=0.70\\paperwidth,at=(current page.center)]{%",
    -- the node reserves a full \baselineskip above the first line but only the
    -- last line's depth below, which leaves the text sitting low in the box
    "\\vspace*{-0.5\\baselineskip}%",
  }, "\n")
  local blocks = pandoc.List({ pandoc.RawBlock("latex", open) })
  blocks:extend(el.content)
  -- The picture is an overlay, but the paragraph it forms still occupies a
  -- line, which shifts the figure underneath relative to the beat before it;
  -- the negative skip takes that line back. (\smash is not an option here:
  -- the node holds a paragraph, which an \hbox cannot.)
  blocks:insert(pandoc.RawBlock("latex",
    "};\n\\end{tikzpicture}\\vspace*{-1.5\\baselineskip}"))
  return blocks
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
