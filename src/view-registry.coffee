{Disposable} = require 'event-kit'
{jQuery} = require './space-pen-extensions'

module.exports =
class ViewRegistry
  constructor: ->
    @views = new WeakMap
    @providers = []

  addViewProvider: (providerSpec) ->
    @providers.push(providerSpec)
    new Disposable =>
      @providers = @providers.filter (provider) -> provider isnt providerSpec

  getView: (object) ->
    return unless object?

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
      object[0]?.__spacePenView ?= object
      object[0]
    else if provider = @findProvider(object)
      element = provider.createView?(object)
      unless element?
        element = new provider.viewConstructor
        element.setModel(object)
      element
    else if viewConstructor = object?.getViewClass?()
      view = new viewConstructor(object)
      view[0].__spacePenView ?= view
      view[0]
    else
      throw new Error("Can't create a view for #{object.constructor.name} instance. Please register a view provider.")

  findProvider: (object) ->
    @providers.find ({modelConstructor}) -> object instanceof modelConstructor
