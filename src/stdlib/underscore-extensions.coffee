_ = require 'underscore'

_.mixin
  remove: (array, element) ->
    index = array.indexOf(element)
    array.splice(index, 1) if index >= 0

  sum: (array) ->
    sum = 0
    sum += elt for elt in array
    sum

  adviseBefore: (object, methodName, advice) ->
    original = object[methodName]
    object[methodName] = (args...) ->
      unless advice.apply(this, args) == false
        original.apply(this, args)

  escapeRegExp: (string) ->
    # Referring to the table here:
    # https://developer.mozilla.org/en/JavaScript/Reference/Global_Objects/regexp
    # these characters should be escaped
    # \ ^ $ * + ? . ( ) | { } [ ]
    # These characters only have special meaning inside of brackets
    # they do not need to be escaped, but they MAY be escaped
    # without any adverse effects (to the best of my knowledge and casual testing)
    # : ! , =
    # my test "~!@#$%^&*(){}[]`/=?+\|-_;:'\",<.>".match(/[\#]/g)

    specials = [
      # order matters for these
      "-"
      "["
      "]"
      # order doesn't matter for any of these
      "/"
      "{"
      "}"
      "("
      ")"
      "*"
      "+"
      "?"
      "."
      "\\"
      "^"
      "$"
      "|"]

    # I choose to escape every character with '\'
    # even though only some strictly require it when inside of []
    regex = RegExp('[' + specials.join('\\') + ']', 'g')
    string.replace(regex, "\\$&");

  humanizeEventName: (eventName, eventDoc) ->
    [namespace, event]  = eventName.split(':')
    return _.capitalize(namespace) unless event?

    namespaceDoc = _.undasherize(namespace)
    eventDoc ?= _.undasherize(event)

    "#{namespaceDoc}: #{eventDoc}"

  capitalize: (word) ->
    if word.toLowerCase() is 'github'
      'GitHub'
    else
      word[0].toUpperCase() + word[1..]

  pluralize: (count=0, singular, plural=singular+'s') ->
    if count is 1
      "#{count} #{singular}"
    else
      "#{count} #{plural}"

  camelize: (string) ->
    string.replace /[_-]+(\w)/g, (m) -> m[1].toUpperCase()

  dasherize: (string) ->
    string = string[0].toLowerCase() + string[1..]
    string.replace /([A-Z])|(_)/g, (m, letter, underscore) ->
      if letter
        "-" + letter.toLowerCase()
      else
        "-"

  undasherize: (string) ->
    string.split('-').map(_.capitalize).join(' ')

  underscore: (string) ->
    string = string[0].toLowerCase() + string[1..]
    string.replace /([A-Z])|(-)/g, (m, letter, dash) ->
      if letter
        "_" + letter.toLowerCase()
      else
        "_"

  losslessInvert: (hash) ->
    inverted = {}
    for key, value of hash
      inverted[value] ?= []
      inverted[value].push(key)
    inverted

  multiplyString: (string, n) ->
    new Array(1 + n).join(string)

  nextTick: (fn) ->
    unless @messageChannel
      @pendingNextTickFns = []
      @messageChannel = new MessageChannel
      @messageChannel.port1.onmessage = =>
        fn() while fn = @pendingNextTickFns.shift()

    @pendingNextTickFns.push(fn)
    @messageChannel.port2.postMessage(0)

  endsWith: (string, suffix) ->
    string.indexOf(suffix, string.length - suffix.length) isnt -1

  valueForKeyPath: (object, keyPath) ->
    keys = keyPath.split('.')
    for key in keys
      object = object[key]
      return unless object?
    object

  setValueForKeyPath: (object, keyPath, value) ->
    keys = keyPath.split('.')
    while keys.length > 1
      key = keys.shift()
      object[key] ?= {}
      object = object[key]
    object[keys.shift()] = value

  compactObject: (object) ->
    newObject = {}
    for key, value of object
      newObject[key] = value if value?
    newObject
