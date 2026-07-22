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
