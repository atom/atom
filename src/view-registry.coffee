{jQuery} = require './space-pen-extensions'

module.exports =
class ViewRegistry
  constructor: ->
    @views = new WeakMap

  getView: (object) ->
    if view = @views.get(object)
      view
    else
      view = @createView(object)
      @views.set(object, view)
      view

  createView: (object) ->
    if object instanceof HTMLElement
      object
    else if object instanceof jQuery
      object[0].__spacePenView ?= object
      object[0]
    else if viewClass = object?.getViewClass?()
      view = new viewClass(object)
      view[0].__spacePenView ?= view
      view[0]
    else
      throw new Error("Can't create a view for #{object.constructor.name} instance. Please register a view provider.")
