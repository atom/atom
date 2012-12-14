{View, $$} = require 'space-pen'
SelectList = require 'select-list'
Editor = require 'editor'
TagGenerator = require 'outline-view/src/tag-generator'
TagReader = require 'outline-view/src/tag-reader'
Point = require 'point'
fs = require 'fs'
$ = require 'jquery'

module.exports =
class OutlineView extends SelectList

  @activate: (rootView) ->
    requireStylesheet 'select-list.css'
    requireStylesheet 'outline-view/src/outline-view.css'
    @instance = new OutlineView(rootView)
    rootView.command 'outline-view:toggle', => @instance.toggle()
    rootView.command 'outline-view:jump-to-declaration', => @instance.jumpToDeclaration()

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
      @attach()

  populate: ->
    tags = []
    callback = (tag) -> tags.push tag
    path = @rootView.getActiveEditor().getPath()
    @setLoading("Generating symbols...")
    new TagGenerator(path, callback).generate().done =>
      if tags.length > 0
        @miniEditor.show()
        @setArray(tags)
      else
        @miniEditor.hide()
        @setError("No symbols found")
        setTimeout (=> @detach()), 2000

  confirmed : (tag) ->
    @cancel()
    @openTag(tag)

  openTag: ({position, file}) ->
    @rootView.openInExistingEditor(file, true, true) if file
    @moveToPosition(position)

  moveToPosition: (position) ->
    editor = @rootView.getActiveEditor()
    editor.scrollToBufferPosition(position, center: true)
    editor.setCursorBufferPosition(position)
    editor.moveCursorToFirstCharacterOfLine()

  cancelled: ->
    @miniEditor.setText('')
    @rootView.focus() if @miniEditor.isFocused

  attach: ->
    @rootView.append(this)
    @miniEditor.focus()

  getTagLine: (tag) ->
    pattern = tag.pattern?.replace(/(^^\/\^)|(\$\/$)/g, '') # Remove leading /^ and trailing $/
    return unless pattern
    for line, index in fs.read(@rootView.project.resolve(tag.file)).split('\n')
      return new Point(index, 0) if pattern is $.trim(line)

  jumpToDeclaration: ->
    editor = @rootView.getActiveEditor()
    matches = TagReader.find(editor)
    return unless matches.length

    if matches.length is 1
      position = @getTagLine(matches[0])
      @openTag(file: matches[0].file, position: position) if position
    else
      tags = []
      for match in matches
        position = @getTagLine(match)
        continue unless position
        tags.push
          file: match.file
          name: fs.base(match.file)
          position: position
      @miniEditor.show()
      @setArray(tags)
      @attach()
