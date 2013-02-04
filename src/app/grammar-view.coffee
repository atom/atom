SelectList = require 'select-list'
{$$} = require 'space-pen'

module.exports =
class GrammarView extends SelectList

  @viewClass: -> "#{super} grammar-view from-top overlay"

  filterKey: 'name'

  initialize: (@editor) ->
    @currentGrammar = @editor.getGrammar()
    @path = @editor.getPath()
    @autoDetect = name: 'Auto Detect'
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
    grammars = new Array(syntax.grammars...)
    grammars.unshift(@autoDetect)
    @setArray(grammars)

  confirmed: (grammar) ->
    @cancel()
    if grammar is @autoDetect
      rootView.project.removeGrammarOverrideForPath(@path)
    else
      rootView.project.addGrammarOverrideForPath(@path, grammar)
    @editor.reloadGrammar()

  attach: ->
    super

    @editor.rootView()?.append(this)
    @miniEditor.focus()
