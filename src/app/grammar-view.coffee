SelectList = require 'select-list'
{$$} = require 'space-pen'

module.exports =
class GrammarView extends SelectList

  @viewClass: -> "#{super} grammar-view from-top overlay mini"

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
      grammarClass = 'active-item'
    else
      grammarClass = 'inactive-item'

    $$ ->
      @li grammar.name, class: grammarClass

  populate: ->
    grammars = new Array(syntax.grammars...)
    grammars.sort (grammarA, grammarB) ->
      if grammarA.scopeName is 'text.plain'
        -1
      else if grammarB.scopeName is 'text.plain'
        1
      else if grammarA.name < grammarB.name
        -1
      else if grammarA.name > grammarB.name
        1
      else
        0
    grammars.unshift(@autoDetect)
    @setArray(grammars)

  confirmed: (grammar) ->
    @cancel()
    if grammar is @autoDetect
      syntax.clearGrammarOverrideForPath(@path)
    else
      syntax.setGrammarOverrideForPath(@path, grammar.scopeName)
    @editor.reloadGrammar()

  attach: ->
    super

    rootView.append(this)
    @miniEditor.focus()
