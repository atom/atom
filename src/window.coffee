$ = require 'jquery'

module.exports =
class Window
  controller: null
  document: null
  nswindow: null
  panes: []

  constructor: (options={}) ->
    @controller = options.controller
    @document = options.document
    @nswindow = options.controller?.window

  addPane: (position, html) ->
    Editor = require 'editor'

    verticalDiv = $('#app-vertical')
    horizontalDiv = $('#app-horizontal')

    el = document.createElement "div"
    el.setAttribute 'class', "pane " + position
    el.innerHTML = html

    el.addEventListener 'DOMNodeInsertedIntoDocument', ->
      Editor.resize()

    el.addEventListener 'DOMNodeRemovedFromDocument', ->
      Editor.resize()

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

  isDirty: ->
    @nswindow.isDocumentEdited()

  # Set the active window's dirty status.
  setDirty: (bool) ->
    @nswindow.setDocumentEdited bool

  inspector:->
    @_inspector ?= WindowController.webView.inspector

  title: ->
    @nswindow.title

  setTitle: (title) ->
    @nswindow.title = title
