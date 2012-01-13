$ = require 'jquery'
BindingSet = require 'binding-set'
Specificity = require 'specificity'

module.exports =
class GlobalKeymap
  bindingSetsBySelector: null

  constructor: ->
    @bindingSets = []

  bindKeys: (selector, bindings) ->
    @bindingSets.unshift(new BindingSet(selector, bindings))

  handleKeyEvent: (event) ->
    currentNode = $(event.target)
    while currentNode.length
      candidateBindingSets = @bindingSets.filter (set) -> currentNode.is(set.selector)
      candidateBindingSets.sort (a, b) -> b.specificity - a.specificity
      for bindingSet in candidateBindingSets
        command = bindingSet.commandForEvent(event)
        if command
          @triggerCommandEvent(event, command)
          return false
        else if command == false
          return false
      currentNode = currentNode.parent()
    true

  reset: ->
    @BindingSets = []

  triggerCommandEvent: (keyEvent, commandName) ->
    commandEvent = $.Event(commandName)
    keyEvent.char = @charForKeyEvent(keyEvent)
    commandEvent.keyEvent = keyEvent
    $(keyEvent.target).trigger(commandEvent)

  charForKeyEvent: (keyEvent) ->
    String.fromCharCode(keyEvent.which).toLowerCase()

