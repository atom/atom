$ = require 'jquery'
BindingSet = require 'binding-set'
Specificity = require 'specificity'

module.exports =
class GlobalKeymap
  bindingSetsBySelector: null

  constructor: ->
    @bindingSets = []

    @bindKeys "*",
      'meta-n': 'newWindow'
      'meta-o': 'open'

    $(document).on 'newWindow', => $native.newWindow()
    $(document).on 'open', => 
      url = $native.openDialog()
      atom.open(url) if url
  

  bindKeys: (selector, bindings) ->
    @bindingSets.unshift(new BindingSet(selector, bindings))

  bindKey: (selector, pattern, eventName) ->
    bindings = {}
    bindings[pattern] = eventName
    @bindKeys(selector, bindings)

  handleKeyEvent: (event) ->
    event.keystroke = @keystrokeStringForEvent(event)
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
    @bindingSets = []

  triggerCommandEvent: (keyEvent, commandName) ->
    commandEvent = $.Event(commandName)
    commandEvent.keyEvent = keyEvent
    $(keyEvent.target).trigger(commandEvent)

  keystrokeStringForEvent: (event) ->
    if /^U\+/i.test event.originalEvent.keyIdentifier
      hexCharCode = event.originalEvent.keyIdentifier.replace(/^U\+/i, '')
      charCode = parseInt(hexCharCode, 16)
      key = @keyFromCharCode(charCode)
    else
      key = event.originalEvent.keyIdentifier.toLowerCase()

    modifiers = ''
    if event.altKey and key isnt 'alt'
      modifiers += 'alt-'
    if event.ctrlKey and key isnt 'ctrl'
      modifiers += 'ctrl-'
    if event.metaKey and key isnt 'meta'
      modifiers += 'meta-'

    if event.shiftKey
      isNamedKey = key.length > 1
      modifiers += 'shift-' if isNamedKey
    else
      key = key.toLowerCase()

    "#{modifiers}#{key}"

  keyFromCharCode: (charCode) ->
    switch charCode
      when 8 then 'backspace'
      when 9 then 'tab'
      when 13 then 'enter'
      when 27 then 'escape'
      when 32 then 'space'
      when 127 then 'delete'
      else String.fromCharCode(charCode)
