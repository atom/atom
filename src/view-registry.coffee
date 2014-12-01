module.exports =
class ViewRegistry
  constructor: (@viewFactory) ->
    @views = new WeakMap

  getView: (object) ->
    return unless object?

    if view = @views.get(object)
      view
    else
      view = @viewFactory.createView(object, viewRegistry: this)
      @views.set(object, view)
      view
