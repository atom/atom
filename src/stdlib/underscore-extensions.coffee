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
      unless advice(args...) == false
        original(args...)

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
