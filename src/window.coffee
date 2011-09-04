$ = require 'jquery'

App  = require 'app'
Pane = require 'pane'

module.exports =
class Window extends Pane
  controller: null
  document: null
  nswindow: null
  panes: []

  keymap:
    'Command-N'       : 'new'
    'Command-O'       : 'open'
    'Command-Shift-O' : 'openURL'
    'Command-Ctrl-K'  : 'showConsole'
    'Command-Ctrl-R'  : 'reload'

  initialize: ->
    @nswindow = @controller?.window

  addPane: ({position, html}) ->
    verticalDiv = $('#app-vertical')
    horizontalDiv = $('#app-horizontal')

    el = document.createElement "div"
    el.setAttribute 'class', "pane " + position
    el.innerHTML = html

    switch position
      when 'top', 'main'
        verticalDiv.prepend el
      when 'left'
        horizontalDiv.prepend el
      when 'bottom'
        verticalDiv.append el
      when 'right'
        horizontalDiv.append el
      else
        throw "I DON'T KNOW HOW TO DEAL WITH #{position}"

  close: ->
    @controller.close()

  reload: ->
    App.newWindow()
    @close()

  isDirty: ->
    @nswindow.isDocumentEdited()

  # Set the active window's dirty status.
  setDirty: (bool) ->
    @nswindow.setDocumentEdited bool

  inspector: ->
    @_inspector ?= WindowController.webView.inspector

  new: ->
    App.newWindow()

  open: (path) ->
    @document?.open path

  openURL: (url) ->
    if url = prompt "Enter URL:"
      App.openURL url

  showConsole: ->
    @inspector().showConsole(1)

  title: ->
    @nswindow.title

  setTitle: (title) ->
    @nswindow.title = title
