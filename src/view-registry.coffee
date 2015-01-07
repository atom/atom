Grim = require 'grim'
{Disposable} = require 'event-kit'

# Essential: `ViewRegistry` handles the association between model and view
# types in Atom. We call this association a View Provider. As in, for a given
# model, this class can provide a view via {::getView}, as long as the
# model/view association was registered via {::addViewProvider}
#
# If you're adding your own kind of pane item, a good strategy for all but the
# simplest items is to separate the model and the view. The model handles
# application logic and is the primary point of API interaction. The view
# just handles presentation.
#
# View providers inform the workspace how your model objects should be
# presented in the DOM. A view provider must always return a DOM node, which
# makes [HTML 5 custom elements](http://www.html5rocks.com/en/tutorials/webcomponents/customelements/)
# an ideal tool for implementing views in Atom.
#
# You can access the `ViewRegistry` object via `atom.views`.
#
# ## Examples
#
# ### Getting the workspace element
#
# ```coffee
# workspaceElement = atom.views.getView(atom.workspace)
# ```
#
# ### Getting An Editor Element
#
# ```coffee
# textEditor = atom.workspace.getActiveTextEditor()
# textEditorElement = atom.views.getView(textEditor)
# ```
#
# ### Getting A Pane Element
#
# ```coffee
# pane = atom.workspace.getActivePane()
# paneElement = atom.views.getView(pane)
# ```
module.exports =
class ViewRegistry
  constructor: ->
    @views = new WeakMap
    @providers = []

  # Essential: Add a provider that will be used to construct views in the
  # workspace's view layer based on model objects in its model layer.
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
  #     DOM node) and have a `::setModel()` method which will be called
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
  addViewProvider: (modelConstructor, createView) ->
    if arguments.length is 1
      Grim.deprecate("atom.views.addViewProvider now takes 2 arguments: a model constructor and a createView function. See docs for details.")
      provider = modelConstructor
    else
      provider = {modelConstructor, createView}

    @providers.push(provider)
    new Disposable =>
      @providers = @providers.filter (p) -> p isnt provider

  # Essential: Get the view associated with an object in the workspace.
  #
  # If you're just *using* the workspace, you shouldn't need to access the view
  # layer, but view layer access may be necessary if you want to perform DOM
  # manipulation that isn't supported via the model API.
  #
  # ## Examples
  #
  # ### Getting An Editor Element
  #
  # ```coffee
  # textEditor = atom.workspace.getActiveTextEditor()
  # textEditorElement = atom.views.getView(textEditor)
  # ```
  #
  # ### Getting A Pane Element
  #
  # ```coffee
  # pane = atom.workspace.getActivePane()
  # paneElement = atom.views.getView(pane)
  # ```
  #
  # ### Getting The Workspace Element
  #
  # ```coffee
  # workspaceElement = atom.views.getView(atom.workspace)
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
    else if object?.jquery
      object[0]
    else if provider = @findProvider(object)
      element = provider.createView?(object)
      unless element?
        element = new provider.viewConstructor
        element.initialize?(object) ? element.setModel?(object)
      element
    else if viewConstructor = object?.getViewClass?()
      view = new viewConstructor(object)
      view[0]
    else
      throw new Error("Can't create a view for #{object.constructor.name} instance. Please register a view provider.")

  findProvider: (object) ->
    @providers.find ({modelConstructor}) -> object instanceof modelConstructor
