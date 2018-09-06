root = document.documentElement
themeName = 'one-light-ui'


module.exports =
  activate: (state) ->
    atom.config.observe "#{themeName}.fontSize", (value) ->
      setFontSize(value)

    atom.config.observe "#{themeName}.tabSizing", (value) ->
      setTabSizing(value)

    atom.config.observe "#{themeName}.tabCloseButton", (value) ->
      setTabCloseButton(value)

    atom.config.observe "#{themeName}.hideDockButtons", (value) ->
      setHideDockButtons(value)

    atom.config.observe "#{themeName}.stickyHeaders", (value) ->
      setStickyHeaders(value)

    # DEPRECATED: This can be removed at some point (added in Atom 1.17/1.18ish)
    # It removes `layoutMode`
    if atom.config.get("#{themeName}.layoutMode")
      atom.config.unset("#{themeName}.layoutMode")

  deactivate: ->
    unsetFontSize()
    unsetTabSizing()
    unsetTabCloseButton()
    unsetHideDockButtons()
    unsetStickyHeaders()


# Font Size -----------------------

setFontSize = (currentFontSize) ->
  root.style.fontSize = "#{currentFontSize}px"

unsetFontSize = ->
  root.style.fontSize = ''


# Tab Sizing -----------------------

setTabSizing = (tabSizing) ->
  root.setAttribute("theme-#{themeName}-tabsizing", tabSizing.toLowerCase())

unsetTabSizing = ->
  root.removeAttribute("theme-#{themeName}-tabsizing")


# Tab Close Button -----------------------

setTabCloseButton = (tabCloseButton) ->
  if tabCloseButton is 'Left'
    root.setAttribute("theme-#{themeName}-tab-close-button", 'left')
  else
    unsetTabCloseButton()

unsetTabCloseButton = ->
  root.removeAttribute("theme-#{themeName}-tab-close-button")


# Dock Buttons -----------------------

setHideDockButtons = (hideDockButtons) ->
  if hideDockButtons
    root.setAttribute("theme-#{themeName}-dock-buttons", 'hidden')
  else
    unsetHideDockButtons()

unsetHideDockButtons = ->
  root.removeAttribute("theme-#{themeName}-dock-buttons")


# Sticky Headers -----------------------

setStickyHeaders = (stickyHeaders) ->
  if stickyHeaders
    root.setAttribute("theme-#{themeName}-sticky-headers", 'sticky')
  else
    unsetStickyHeaders()

unsetStickyHeaders = ->
  root.removeAttribute("theme-#{themeName}-sticky-headers")
