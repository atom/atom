SelectList = require 'select-list'
{$$} = require 'space-pen'

module.exports =
class GrammarView extends SelectList

  @viewClass: -> "#{super} grammar-view"

  filterKey: 'name'

  initialize: (@editor) ->
    @currentGrammar = @editor.getGrammar()
    @path = @editor.getPath()
    requireStylesheet 'grammar-view.css'
    @command 'editor:select-grammar', =>
      @cancel()
      false
    super

    @populate()
    @attach()

  itemForElement: (grammar) ->
    if grammar is @currentGrammar
      grammarClass = 'current-grammar'
    else
      grammarClass = 'grammar'

    $$ ->
      @li grammar.name, class: grammarClass

  populate: ->
    @setArray(syntax.grammars)

  cancelled: ->
    @miniEditor.setText('')
    @editor.rootView()?.focus() if @miniEditor.isFocused

  confirmed: (grammar) ->
    @cancel()
    syntax.addGrammarForPath(@path, grammar)
    @editor.reloadGrammar()

  attach: ->
    @editor.rootView()?.append(this)
    @miniEditor.focus()
