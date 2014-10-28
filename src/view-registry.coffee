{Disposable} = require 'event-kit'
{jQuery} = require './space-pen-extensions'

# Essential
module.exports =
class ViewRegistry
  constructor: ->
    @views = new WeakMap
    @providers = []

  # Essential: Add a provider that will be used to construct views in the
  # workspace's view layer based on model objects in its model layer.
  #
  # If you're adding your own kind of pane item, a good strategy for all but the
  # simplest items is to separate the model and the view. The model handles
  # application logic and is the primary point of API interaction. The view
  # just handles presentation.
  #
  # Use view providers to inform the workspace how your model objects should be
  # presented in the DOM. A view provider must always return a DOM node, which
  # makes [HTML 5 custom elements](http://www.html5rocks.com/en/tutorials/webcomponents/customelements/)
  # an ideal tool for implementing views in Atom.
  #
  # ## Examples
  #
  # Text editors are divided into a model and a view layer, so when you interact
  # with methods like `atom.workspace.getActiveTextEditor()` you're only going
  # to get the model object. We display text editors on screen by teaching the
  # workspace what view constructor it should use to represent them:
  #
  # ```coffee
  # atom.views.addViewProvider
  #   modelConstructor: TextEditor
  #   viewConstructor: TextEditorElement
  # ```
  #
  # * `providerSpec` {Object} containing the following keys:
  #   * `modelConstructor` Constructor {Function} for your model.
  #   * `viewConstructor` (Optional) Constructor {Function} for your view. It
  #     should be a subclass of `HTMLElement` (that is, your view should be a
  #     DOM node) and   have a `::setModel()` method which will be called
  #     immediately after construction. If you don't supply this property, you
  #     must supply the `createView` property with a function that never returns
  #     `undefined`.
  #   * `createView` (Optional) Factory {Function} that must return a subclass
  #     of `HTMLElement` or `undefined`. If this property is not present or the
  #     function returns `undefined`, the view provider will fall back to the
  #     `viewConstructor` property. If you don't provide this property, you must
  #     provider a `viewConstructor` property.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to remove the
  # added provider.
  addViewProvider: (providerSpec) ->
    @providers.push(providerSpec)
    new Disposable =>
      @providers = @providers.filter (provider) -> provider isnt providerSpec

  # Essential: Get the view associated with an object in the workspace.
  #
  # If you're just *using* the workspace, you shouldn't need to access the view
  # layer, but view layer access may be necessary if you want to perform DOM
  # manipulation that isn't supported via the model API.
  #
  # ## Examples
  #
  # ### Getting An Editor View
  # ```coffee
  # textEditor = atom.workspace.getActiveTextEditor()
  # textEditorView = atom.views.getView(textEditor)
  # ```
  #
  # ### Getting A Pane View
  # ```coffee
  # pane = atom.workspace.getActivePane()
  # paneView = atom.views.getView(pane)
  # ```
  #
  # ### Getting The Workspace View
  #
  # ```coffee
  # workspaceView = atom.views.getView(atom.workspace)
  # ```
  #
  # * `object` The object for which you want to retrieve a view. This can be a
  #   pane item, a pane, or the workspace itself.
  #
  # Returns a DOM element.
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
