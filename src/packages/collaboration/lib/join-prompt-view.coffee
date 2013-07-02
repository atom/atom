{View} = require 'space-pen'
Editor = require 'editor'
$ = require 'jquery'
_ = require 'underscore'
Guid = require 'guid'

module.exports =
class JoinPromptView extends View
  @activate: -> new Prompt

  @content: ->
    @div class: 'overlay from-top', =>
      @subview 'miniEditor', new Editor(mini: true)
      @div class: 'message', outlet: 'message', 'Enter a session id to join'

  initialize: (@confirmed) ->
    @miniEditor.on 'focusout', => @remove()
    @on 'core:confirm', => @confirm()
    @on 'core:cancel', => @remove()

    clipboard = pasteboard.read()[0]
    if Guid.isGuid(clipboard)
      @miniEditor.setText(clipboard)

    @attach()

  beforeRemove: ->
    @previouslyFocusedElement?.focus()
    @miniEditor.setText('')

  confirm: ->
    @confirmed(@miniEditor.getText())
    @remove()

  attach: ->
    @previouslyFocusedElement = $(':focus')
    rootView.append(this)
    @miniEditor.focus()
