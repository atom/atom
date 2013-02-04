{$$} = require 'space-pen'
SelectList = require 'select-list'
TagGenerator = require 'symbols-view/src/tag-generator'
TagReader = require 'symbols-view/src/tag-reader'
Point = require 'point'
fs = require 'fs'
$ = require 'jquery'

module.exports =
class SymbolsView extends SelectList

  @activate: (rootView) ->
    @instance = new SymbolsView(rootView)

  @viewClass: -> "#{super} symbols-view overlay from-top"

  filterKey: 'name'

  initialize: (@rootView) ->
    super

  itemForElement: ({position, name, file}) ->
    $$ ->
      @li =>
        @div name, class: 'label'
        @div class: 'right', =>
          if position
            text = "Line #{position.row + 1}"
          else
            text = fs.base(file)
          @div text, class: 'function-details'

  toggleFileSymbols: ->
    if @hasParent()
      @cancel()
    else
      @populateFileSymbols()
      @attach()

  populateFileSymbols: ->
    tags = []
    callback = (tag) -> tags.push tag
    path = @rootView.getActiveEditor().getPath()
    @setLoading("Generating symbols...")
    new TagGenerator(path, callback).generate().done =>
      if tags.length > 0
        @miniEditor.show()
        @maxItem = Infinity
        @setArray(tags)
      else
        @miniEditor.hide()
        @setError("No symbols found")
        setTimeout (=> @detach()), 2000

  toggleProjectSymbols: ->
    if @hasParent()
      @cancel()
    else
      @populateProjectSymbols()
      @attach()

  populateProjectSymbols: ->
    @setLoading("Loading symbols...")
    TagReader.getAllTags(@rootView.project).done (tags) =>
      if tags.length > 0
        @miniEditor.show()
        @maxItems = 10
        @setArray(tags)
      else
        @miniEditor.hide()
        @setError("No symbols found")
        setTimeout (=> @detach()), 2000

  confirmed : (tag) ->
    @cancel()
    @openTag(tag)

  openTag: (tag) ->
    position = tag.position
    position = @getTagLine(tag) unless position
    @rootView.open(tag.file, {changeFocus: true, allowActiveEditorChange:true}) if tag.file
    @moveToPosition(position) if position

  moveToPosition: (position) ->
    editor = @rootView.getActiveEditor()
    editor.scrollToBufferPosition(position, center: true)
    editor.setCursorBufferPosition(position)
    editor.moveCursorToFirstCharacterOfLine()

  attach: ->
    super

    @rootView.append(this)
    @miniEditor.focus()

  getTagLine: (tag) ->
    pattern = $.trim(tag.pattern?.replace(/(^^\/\^)|(\$\/$)/g, '')) # Remove leading /^ and trailing $/
    return unless pattern
    file = @rootView.project.resolve(tag.file)
    return unless fs.isFile(file)
    for line, index in fs.read(file).split('\n')
      return new Point(index, 0) if pattern is $.trim(line)

  goToDeclaration: ->
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
