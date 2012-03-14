_ = require 'underscore'

_.mixin
  remove: (array, element) ->
    array.splice(array.indexOf(element), 1)

