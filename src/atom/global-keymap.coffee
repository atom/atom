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
    if event.type is 'keypress'
      char = String.fromCharCode event.which
    else
      char = @keyCodeToChar[event.which]

    modifiers = ''
    if event.altKey and char isnt 'alt'
      modifiers += 'alt-'
    if event.ctrlKey and char isnt 'ctrl'
      modifiers += 'ctrl-'
    if event.metaKey and char isnt 'meta'
      modifiers += 'meta-'

    if event.shiftKey
      if event.type is 'keypress'
        "#{modifiers}#{char}"
      else if shiftChar = @shiftKeyCodeToChar[event.which]
        "#{modifiers}#{shiftChar}"
      else if char is 'shift'
        "#{modifiers}shift"
      else if (char)
        "#{modifiers}shift-#{char}"
      else
        null
    else if char
      "#{modifiers}#{char}"
    else
      null

  keyCodeToChar:
    8: 'backspace', 9: 'tab', 13: 'enter', 16: 'shift', 17: 'ctrl',
    18: 'alt', 19: 'pause', 20: 'capslock', 27: 'esc', 32: 'space',
    33: 'pageup', 34: 'pagedown', 35: 'end', 36: 'home', 37: 'left',
    38: 'up', 39: 'right', 40: 'down', 45: 'insert', 46: 'del',
    48: '0', 49: '1', 50: '2', 51: '3', 52: '4', 53: '5', 54: '6',
    55: '7', 56: '8', 57: '9', 65: 'a', 66: 'b', 67: 'c', 68: 'd',
    69: 'e', 70: 'f', 71: 'g', 72: 'h', 73: 'i', 74: 'j', 75: 'k',
    76: 'l', 77: 'm', 78: 'n', 79: 'o', 80: 'p', 81: 'q', 82: 'r',
    83: 's', 84: 't', 85: 'u', 86: 'v', 87: 'w', 88: 'x', 89: 'y',
    90: 'z', 91: 'meta', 93: 'meta', 96: '0', 97: '1', 98: '2',
    99: '3', 100: '4', 101: '5', 102: '6', 103: '7', 104: '8',
    105: '9', 106: '*', 107: '+', 109: '-', 110: '.', 111: '/',
    112: 'f1', 113: 'f2', 114: 'f3', 115: 'f4', 116: 'f5', 117: 'f6',
    118: 'f7', 119: 'f8', 120: 'f9', 121: 'f10', 122: 'f11',
    123: 'f12', 144: 'numlock', 145: 'scroll', 186: ';', 187: '=',
    188: ',', 189: '-', 190: '.', 191: '/', 192: '`', 219: '[',
    220: '\\', 221: ']', 222: '\''

  shiftKeyCodeToChar:
    48: ')', 49: '!', 50: '@', 51: '#', 52: '$', 53: '%', 54: '^',
    55: '&', 56: '*', 57: '(', 65: 'A', 66: 'B', 67: 'C', 68: 'D',
    69: 'E', 70: 'F', 71: 'G', 72: 'H', 73: 'I', 74: 'J', 75: 'K',
    76: 'L', 77: 'M', 78: 'N', 79: 'O', 80: 'P', 81: 'Q', 82: 'R',
    83: 'S', 84: 'T', 85: 'U', 86: 'V', 87: 'W', 88: 'X', 89: 'Y',
    90: 'Z', 186: ':', 187: '+', 188: '<', 189: '_', 190: '>',
    191: '?', 192: '~', 219: '{', 220: '|', 221: '}', 222: '"'

