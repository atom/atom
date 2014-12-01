{Disposable} = require 'event-kit'
Grim = require 'grim'
ViewRegistry = require './view-registry'

# Essential: The `ViewFactory` can creates the appropriate views for a given
# model object based on recipes registered via {::addViewProvider}. It is
# available via `atom.views` as a singleton object.
module.exports =
class ViewFactory
  constructor: ->
    @providers = []
    @deprecatedViewRegistry = new ViewRegistry(this)

  # Essential: Add a provider that will be used by {::createView} to construct
  # an element based on the constructor of the given model object.
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

  getView: (object) ->
    Grim.deprecate("Call ::getView on the workspace element instead. The atom.views global is only intended to create views.")
    @deprecatedViewRegistry.getView(object)

  # Essential: Create an element for the given model object based on providers
  # registered via {::addViewProvider}.
  #
  # ## Examples
  #
  # ### Creating a workspace element in specs
  # ```coffee
  # workspaceElement = atom.views.createView(atom.workspace)
  # ```
  #
  # * `object` The model for which to create the view. A view provider matching
  #   its constructor must be registered.
  # * `params` (optional) An {Object} with which to initialize the view. If the
  #   selected view provider has a `createView` method, the params will be
  #   passed to it. If the view provider has a `viewConstructor` method,
  #   `initialize` will be called on the element after creation with the
  #   given params.
  #
  # Returns a DOM element.
  createView: (object, params) ->
    view =
      if object instanceof HTMLElement
        object
      else if object?.jquery
        object[0]?.__spacePenView ?= object
        object[0]
      else if provider = @findProvider(object)
        params ?= {}
        params.viewFactory = this
        params.model = object
        element = provider.createView?(params)
        unless element?
          element = new provider.viewConstructor
          if not (typeof element.initialize is 'function') and (typeof element.setModel is 'function')
            Grim.deprecate("Define `::initialize` instead of `::setModel` in your view. It will be passed a params hash including the model.")
            element.setModel(object)
          else
            element.initialize(params)
        element
      else if viewConstructor = object?.getViewClass?()
        Grim.deprecate("Add a view provider for your object on atom.views instead of implementing `::getViewClass`.")
        view = new viewConstructor(object)
        view[0].__spacePenView ?= view
        view[0]
      else
        throw new Error("Can't create a view for #{object.constructor.name} instance. Please register a view provider.")
    @deprecatedViewRegistry.views.set(object, view)
    view

  findProvider: (object) ->
    @providers.find ({modelConstructor}) -> object instanceof modelConstructor
