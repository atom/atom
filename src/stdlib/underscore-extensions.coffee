_ = require 'underscore'

_.mixin
  remove: (array, element) ->
    index = array.indexOf(element)
    array.splice(index, 1) if index >= 0

  sum: (array) ->
    sum = 0
    sum += elt for elt in array
    sum
