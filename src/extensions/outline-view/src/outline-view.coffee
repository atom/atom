{View, $$} = require 'space-pen'
SelectList = require 'app/select-list'
Editor = require 'app/editor'
TagGenerator = require 'outline-view/src/tag-generator'

module.exports =
class OutlineView extends SelectList

  @activate: (rootView) ->
    requireStylesheet 'select-list.css'
    requireStylesheet 'outline-view/src/outline-view.css'
    @instance = new OutlineView(rootView)
    rootView.command 'outline-view:toggle', => @instance.toggle()

  @viewClass: -> "#{super} outline-view"

  filterKey: 'name'

  initialize: (@rootView) ->
    super

  itemForElement: ({position, name}) ->
    $$ ->
      @li =>
        @div name, class: 'function-name'
        @div class: 'right', =>
          @div "Line #{position.row + 1}", class: 'function-line'
        @div class: 'clear-float'

  toggle: ->
    if @hasParent()
      @cancel()
    else
      @populate()

  populate: ->
    tags = []
    callback = (tag) -> tags.push tag
    path = @rootView.getActiveEditor().getPath()
    new TagGenerator(path, callback).generate().done =>
      if tags.length > 0
        @miniEditor.show()
        @setArray(tags)
      else
        @miniEditor.hide()
        @setError("No symbols found")
        setTimeout (=> @detach()), 2000

      @attach()

  confirmed : ({position, name}) ->
    @cancel()
    @rootView.getActiveEditor().setCursorBufferPosition(position)

  cancelled: ->
    @miniEditor.setText('')
    @rootView.focus() if @miniEditor.isFocused

  attach: ->
    @rootView.append(this)
    @miniEditor.focus()
