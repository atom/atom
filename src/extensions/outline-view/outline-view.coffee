{View, $$} = require 'space-pen'
SelectList = require 'select-list'
stringScore = require 'stringscore'
fuzzyFilter = require 'fuzzy-filter'
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
      @populate()
      @attach()

  populate: ->
    editor = @rootView.getActiveEditor()
    session = editor.activeEditSession
    buffer = session.buffer
    language = session.tokenizedBuffer.languageMode

    functions = []
    functionTester = (scope) ->
      scope.indexOf('entity.name.function.') is 0
    registerFunction = (row, column, name) ->
      return unless name.length > 0
      functions.push
        row: row
        column: column
        name: name

    for row in [0...editor.getLineCount()]
      line = buffer.lineForRow(row)
      continue unless line.length
      {tokens} = language.getLineTokens(line)
      name = ''
      column = 0
      for token in tokens
        if _.find(token.scopes, functionTester)
          name += token.value
        else
          registerFunction(row, column, name)
          column += token.value.length
          name = ''
      registerFunction(row, column, name)

    @setArray(functions)

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
