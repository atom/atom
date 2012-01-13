_ = require 'underscore'
$ = require 'jquery'
Specificity = require 'specificity'

module.exports =
class BindingSet
  namedKeys:
    backspace: 8, tab: 9, clear: 12, enter: 13, 'return': 13,
    esc: 27, escape: 27, space: 32, left: 37, up: 38, right: 39,
    down: 40, del: 46, 'delete': 46, home: 36, end: 35, pageup: 33,
    pagedown: 34, ',': 188, '.': 190, '/': 191, '`': 192, '-': 189,
    '=': 187, ';': 186, '\'': 222, '[': 219, ']': 221, '\\': 220

  selector: null
  bindingMap: null
  bindingFunction: null

  constructor: (@selector, mapOrFunction) ->
    if _.isFunction(mapOrFunction)
      @bindingFunction = mapOrFunction
    else
      @bindingMap = mapOrFunction
    @specificity = Specificity(@selector)

  commandForEvent: (event) ->
    return @bindingFunction(event) if @bindingFunction
    for pattern, command of @bindingMap
      return command if @eventMatchesPattern(event, pattern)
    null

  eventMatchesPattern: (event, pattern) ->
    pattern = @parseKeyPattern pattern
    pattern.ctrlKey == event.ctrlKey and
      pattern.altKey == event.altKey and
      pattern.shiftKey == event.shiftKey and
      pattern.metaKey == event.metaKey and
      pattern.which == event.which

  parseKeyPattern: (pattern) ->
    pattern = pattern.replace(/<|>/g, "")
    [modifiers..., key] = pattern.split '-'

    modifiers.push 'shift' if key == key.toUpperCase() and key.toUpperCase() != key.toLowerCase()

    if @namedKeys[key]
      charCode = @namedKeys[key]
      key = null
    else
      charCode = key.toUpperCase().charCodeAt 0

    ctrlKey: 'ctrl' in modifiers
    altKey: 'alt' in modifiers
    shiftKey: 'shift' in modifiers
    metaKey: 'meta' in modifiers
    which: charCode
    key: key

