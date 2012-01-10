$ = require 'jquery'
BindingSet = require 'binding-set'

module.exports =
class KeyEventHandler
  bindingSetsBySelector: null

  constructor: ->
    @bindingSets = []

  bindKeys: (selector, bindings) ->
    @bindingSets.push(new BindingSet(selector, bindings))

  handleKeypress: (event) ->
    currentNode = event.target
    while currentNode
      for bindingSet in @bindingSets
        if $(currentNode).is(bindingSet.selector)
          if command = bindingSet.commandForEvent(event)
            $(event.target).trigger(command)
            return
      currentNode = currentNode.parentNode

