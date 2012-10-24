{View, $$} = require 'space-pen'
SelectList = require 'select-list'
_ = require 'underscore'
Editor = require 'editor'
ChildProcess = require 'child-process'

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

  parsePrefix: (section = "") ->
    if section.indexOf('class:') is 0
      section.substring(6)
    else if section.indexOf('namespace:') is 0
      section.substring(10)
    else if section.indexOf('file:') is 0
      section.substring(5)
    else if section.indexOf('signature:') is 0
      section.substring(10)
    else
      section

  parseTagLine: (line) ->
    sections = line.split('\t')
    return null if sections.length < 4

    label = sections[0]
    line = parseInt(sections[2]) - 1
    if prefix = @parsePrefix(sections[4])
      label = "#{prefix}::#{label}"
    if signature = @parsePrefix(sections[5])
      label = "#{label}#{signature}"

    tag =
      row: line
      column: 0
      name: label

    return tag

  populate: ->
    tags = []
    options =
      bufferLines: true
      stdout: (data) =>
        lines = data.split('\n')
        for line in lines
          tag = @parseTagLine(line)
          tags.push(tag) if tag
        if tags.length > 0
          @setArray(tags)
          @attach()

    path = @rootView.getActiveEditor().getPath()
    command = "ctags --fields=+KS -nf - #{path}"
    deferred = ChildProcess.exec command, options

  confirmed : ({row, column, name}) ->
    @cancel()
    @rootView.getActiveEditor().setCursorBufferPosition([row, column])

  cancelled: ->
    @miniEditor.setText('')
    @rootView.focus() if @miniEditor.isFocused

  attach: ->
    @rootView.append(this)
    @miniEditor.focus()
