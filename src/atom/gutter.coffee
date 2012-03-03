{View, $$} = require 'space-pen'

$ = require 'jquery'
_ = require 'underscore'

module.exports =
class Gutter extends View
  @content: ->
    @div class: 'gutter'

  renderLineNumbers: (screenLines) ->
    @empty()
    for screenLine, i in screenLines    
      @append $$ ->
        @div {class: 'line-number'}, i + 1
