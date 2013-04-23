SelectList = require 'select-list'
Editor = require 'editor'
{$$} = require 'space-pen'
_ = require 'underscore'

module.exports =
class GrammarSelector extends SelectList
  @viewClass: -> "#{super} grammar-selector from-top overlay mini"

  @activate: ->
    rootView.command 'grammar-selector:show', '.editor', => new GrammarSelector()

  filterKey: 'name'

  initialize: ->
    @editor = rootView.getActiveView()
    return unless @editor instanceof Editor
    @currentGrammar = @editor.getGrammar()
    @path = @editor.getPath()
    @autoDetect = name: 'Auto Detect'
    @command 'grammar-selector:show', =>
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
    grammars = _.reject grammars, (grammar) -> grammar is syntax.nullGrammar
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
