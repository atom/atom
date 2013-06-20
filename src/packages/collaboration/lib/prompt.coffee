{View} = require 'space-pen'
Editor = require 'editor'
$ = require 'jquery'
Point = require 'point'
_ = require 'underscore'

module.exports =
class Prompt extends View
  @activate: -> new Prompt

  @content: ({message}) ->
    @div class: 'overlay from-top mini', =>
      @subview 'miniEditor', new Editor(mini: true)
      @div class: 'message', outlet: 'message', message

  initialize: (message, @confirmed) ->
    @miniEditor.on 'focusout', => @remove()
    @on 'core:confirm', => @confirm()
    @on 'core:cancel', => @remove()
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
