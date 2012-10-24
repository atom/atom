{View, $$} = require 'space-pen'
SelectList = require 'select-list'
_ = require 'underscore'
Editor = require 'editor'
TagGenerator = require 'outline-view/tag-generator'

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

  populate: ->
    tags = []
    callback = (tag) ->
      tags.push tag
    path = @rootView.getActiveEditor().getPath()
    new TagGenerator(path, callback).generate().done =>
      if tags.length > 0
          @setArray(tags)
          @attach()

  confirmed : ({row, column, name}) ->
    @cancel()
    @rootView.getActiveEditor().setCursorBufferPosition([row, column])

  cancelled: ->
    @miniEditor.setText('')
    @rootView.focus() if @miniEditor.isFocused

  attach: ->
    @rootView.append(this)
    @miniEditor.focus()
