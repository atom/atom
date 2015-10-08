{find} = require 'underscore-plus'
Grim = require 'grim'
{Disposable} = require 'event-kit'
_ = require 'underscore-plus'

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
  documentUpdateRequested: false
  documentReadInProgress: false
  performDocumentPollAfterUpdate: false
  debouncedPerformDocumentPoll: null
  minimumPollInterval: 200

  constructor: ->
    @views = new WeakMap
    @providers = []
    @documentWriters = []
    @documentReaders = []
    @documentPollers = []

    @observer = new MutationObserver(@requestDocumentPoll)
    @debouncedPerformDocumentPoll = _.throttle(@performDocumentPoll, @minimumPollInterval).bind(this)

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
  # atom.views.addViewProvider TextEditor, (textEditor) ->
  #   textEditorElement = new TextEditorElement
  #   textEditorElement.initialize(textEditor)
  #   textEditorElement
  # ```
  #
  # * `modelConstructor` Constructor {Function} for your model.
  # * `createView` Factory {Function} that is passed an instance of your model
  #   and must return a subclass of `HTMLElement` or `undefined`.
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
  # ## View Resolution Algorithm
  #
  # The view associated with the object is resolved using the following
  # sequence
  #
  #  1. Is the object an instance of `HTMLElement`? If true, return the object.
  #  2. Does the object have a property named `element` with a value which is
  #     an instance of `HTMLElement`? If true, return the property value.
  #  3. Is the object a jQuery object, indicated by the presence of a `jquery`
  #     property? If true, return the root DOM element (i.e. `object[0]`).
  #  4. Has a view provider been registered for the object? If true, use the
  #     provider to create a view associated with the object, and return the
  #     view.
  #
  # If no associated view is returned by the sequence an error is thrown.
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
    else if object?.element instanceof HTMLElement
      object.element
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
    find @providers, ({modelConstructor}) -> object instanceof modelConstructor

  updateDocument: (fn) ->
    @documentWriters.push(fn)
    @requestDocumentUpdate() unless @documentReadInProgress
    new Disposable =>
      @documentWriters = @documentWriters.filter (writer) -> writer isnt fn

  readDocument: (fn) ->
    @documentReaders.push(fn)
    @requestDocumentUpdate()
    new Disposable =>
      @documentReaders = @documentReaders.filter (reader) -> reader isnt fn

  pollDocument: (fn) ->
    @startPollingDocument() if @documentPollers.length is 0
    @documentPollers.push(fn)
    new Disposable =>
      @documentPollers = @documentPollers.filter (poller) -> poller isnt fn
      @stopPollingDocument() if @documentPollers.length is 0

  pollAfterNextUpdate: ->
    @performDocumentPollAfterUpdate = true

  clearDocumentRequests: ->
    @documentReaders = []
    @documentWriters = []
    @documentPollers = []
    @documentUpdateRequested = false
    @stopPollingDocument()

  requestDocumentUpdate: ->
    unless @documentUpdateRequested
      @documentUpdateRequested = true
      requestAnimationFrame(@performDocumentUpdate)

  performDocumentUpdate: =>
    @documentUpdateRequested = false
    writer() while writer = @documentWriters.shift()

    @documentReadInProgress = true
    reader() while reader = @documentReaders.shift()
    @performDocumentPoll() if @performDocumentPollAfterUpdate
    @performDocumentPollAfterUpdate = false
    @documentReadInProgress = false

    # process updates requested as a result of reads
    writer() while writer = @documentWriters.shift()

  startPollingDocument: ->
    window.addEventListener('resize', @requestDocumentPoll)
    @observer.observe(document, {subtree: true, childList: true, attributes: true})

  stopPollingDocument: ->
    window.removeEventListener('resize', @requestDocumentPoll)
    @observer.disconnect()

  requestDocumentPoll: =>
    if @documentUpdateRequested
      @performDocumentPollAfterUpdate = true
    else
      @debouncedPerformDocumentPoll()

  performDocumentPoll: ->
    poller() for poller in @documentPollers
    return
