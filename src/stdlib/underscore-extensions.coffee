_ = require 'underscore'

_.mixin
  remove: (array, element) ->
    array.splice(array.indexOf(element), 1)

  sum: (array) ->
    sum = 0
    sum += elt for elt in array
    sum
