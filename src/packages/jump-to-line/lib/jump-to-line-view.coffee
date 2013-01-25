{View} = require 'space-pen'
Editor = require 'editor'
$ = require 'jquery'
Point = require 'point'

module.exports =
class JumpToLineView extends View

  @activate: (rootView) -> new JumpToLineView(rootView)

  @content: ->
    @div class: 'jump-to-line', =>
      @subview 'miniEditor', new Editor(mini: true)
      @div class: 'message', outlet: 'message'

  initialize: (@rootView) ->
    @miniEditor.on 'focusout', => @detach() if @hasParent()
    @on 'core:confirm', => @confirm()
    @on 'core:cancel', => @detach() if @hasParent()

    @miniEditor.preempt 'textInput', (e) =>
      false unless e.originalEvent.data.match(/[0-9]/)

  toggle: ->
    if @hasParent()
      @detach()
    else
      @attach()

  detach: ->
    @miniEditor.setText('')
    @previouslyFocusedElement?.focus()

    super

  confirm: ->
    lineNumber = @miniEditor.getText()
    editor = rootView.getActiveEditor()

    @detach()

    return unless editor and lineNumber.length
    position = new Point(parseInt(lineNumber - 1, 0))
    editor.scrollToBufferPosition(position, center: true)
    editor.setCursorBufferPosition(position)
    editor.moveCursorToFirstCharacterOfLine()

  attach: ->
    @previouslyFocusedElement = $(':focus')
    @rootView.append(this)
    @message.text("Enter a line number 1-#{@rootView.getActiveEditor().getLineCount()}")
    @miniEditor.focus()
