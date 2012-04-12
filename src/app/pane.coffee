{View} = require 'space-pen'

module.exports =
class Pane extends View
  @content: (wrappedView) ->
    @div class: 'pane', =>
      @subview 'wrappedView', wrappedView

  @deserialize: ({wrappedView}, rootView) ->
    new Pane(rootView.deserializeView(wrappedView))

  serialize: ->
    viewClass: "Pane"
    wrappedView: @wrappedView.serialize()