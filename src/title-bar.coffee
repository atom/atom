module.exports =
class TitleBar
  constructor: ({@workspace, @themes, @applicationDelegate}) ->
    @element = document.createElement('div')
    @element.classList.add('title-bar')

    @titleElement = document.createElement('div')
    @titleElement.classList.add('title')
    @element.appendChild(@titleElement)

    @element.addEventListener 'dblclick', @dblclickHandler

    @workspace.onDidChangeActivePaneItem => @updateTitle()
    @themes.onDidChangeActiveThemes => @updateWindowSheetOffset()

    @updateTitle()
    @updateWindowSheetOffset()

  dblclickHandler: =>
    # User preference deciding which action to take on a title bar double-click
    switch @applicationDelegate.getUserDefault('AppleActionOnDoubleClick', 'string')
      when 'Minimize'
        @applicationDelegate.minimizeWindow()
      when 'Maximize'
        if @applicationDelegate.isWindowMaximized()
          @applicationDelegate.unmaximizeWindow()
        else
          @applicationDelegate.maximizeWindow()

  updateTitle: ->
    @titleElement.textContent = document.title

  updateWindowSheetOffset: ->
    @applicationDelegate.getCurrentWindow().setSheetOffset(@element.offsetHeight)
