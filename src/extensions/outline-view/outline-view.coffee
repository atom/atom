{View, $$} = require 'space-pen'
SelectList = require 'select-list'
_ = require 'underscore'
Editor = require 'editor'

module.exports =
class OutlineView extends SelectList

  @activate: (rootView) ->
    requireStylesheet 'select-list.css'
    requireStylesheet 'outline-view/outline-view.css'
    @instance = new OutlineView(rootView)
    rootView.command 'outline-view:toggle', => @instance.toggle()

  @viewClass: -> "#{super} outline-view"

  filterKey: 'name'

  initialize: (@rootView) ->
    super

  itemForElement: ({row, name}) ->
    $$ ->
      @li =>
        @div name, class: 'function-name'
        @div class: 'right', =>
          @div "Line #{row}", class: 'function-line'
        @div class: 'clear-float'

  toggle: ->
    if @hasParent()
      @cancel()
    else
      @attach() if @populate()

  populate: ->
    editor = @rootView.getActiveEditor()
    session = editor.activeEditSession
    language = session.tokenizedBuffer.languageMode.grammar.name
    return false unless language is "CoffeeScript"

    functions = []
    functionRegex = /(\s*)(@?[a-zA-Z$_]+)\s*(=|\:)\s*(\([^\)]*\))?\s*(-|=)>/
    lineCount = editor.getLineCount()
    for row in [0...lineCount]
      line = session.buffer.lineForRow(row)
      continue unless line.length
      matches = line.match(functionRegex)
      if matches
        functions.push
          row: row
          column: matches[1].length
          name: matches[2]
    @setArray(functions)
    true

  confirmed : ({row, column, name}) ->
    return unless name.length
    @cancel()
    @rootView.getActiveEditor().setCursorBufferPosition([row, column])

  cancelled: ->
    @miniEditor.setText('')
    @rootView.focus() if @miniEditor.isFocused

  attach: ->
    @rootView.append(this)
    @miniEditor.focus()
