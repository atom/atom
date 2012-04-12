module.exports =
class Pane
  @content: (view) ->
    @div class: 'pane', =>
      @subview 'view', view
