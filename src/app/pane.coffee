{View} = require 'space-pen'

module.exports =
class Pane extends View
  @content: (content) ->
    @div class: 'pane', =>
      @subview 'content', content
