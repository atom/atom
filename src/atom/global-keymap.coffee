$ = require 'jquery'
BindingSet = require 'binding-set'
Specificity = require 'specificity'

module.exports =
class GlobalKeymap
  bindingSetsBySelector: null

  constructor: ->
    @bindingSets = []

  bindKeys: (selector, bindings) ->
    @bindingSets.push(new BindingSet(selector, bindings))

  handleKeyEvent: (event) ->
    currentNode = $(event.target)
    while currentNode isnt document
      candidateBindingSets = @bindingSets.filter (set) -> currentNode.is(set.selector)
      candidateBindingSets.sort (a, b) -> b.specificity - a.specificity
      for bindingSet in candidateBindingSets
        if command = bindingSet.commandForEvent(event)
          $(event.target).trigger(command)
          return
      currentNode = currentNode.parent()

