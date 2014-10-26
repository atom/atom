{deprecate} = require 'grim'
_ = require 'underscore-plus'
{join} = require 'path'
{Model} = require 'theorist'
Q = require 'q'
Serializable = require 'serializable'
Delegator = require 'delegato'
{Emitter, Disposable, CompositeDisposable} = require 'event-kit'
Grim = require 'grim'
TextEditor = require './text-editor'
PaneContainer = require './pane-container'
Pane = require './pane'
Panel = require './panel'
PanelElement = require './panel-element'
PanelContainer = require './panel-container'
PanelContainerElement = require './panel-container-element'
ViewRegistry = require './view-registry'
WorkspaceElement = require './workspace-element'

# Essential: Represents the state of the user interface for the entire window.
# An instance of this class is available via the `atom.workspace` global.
#
# Interact with this object to open files, be notified of current and future
# editors, and manipulate panes. To add panels, you'll need to use the
# {WorkspaceView} class for now until we establish APIs at the model layer.
#
# * `editor` {TextEditor} the new editor
#
module.exports =
class Workspace extends Model
  atom.deserializers.add(this)
  Serializable.includeInto(this)

  @delegatesProperty 'activePane', 'activePaneItem', toProperty: 'paneContainer'

  @properties
    viewRegistry: null
    paneContainer: null
    fullScreen: false
    destroyedItemUris: -> []

  constructor: (params) ->
    super

    @emitter = new Emitter
    @openers = []

    @viewRegistry ?= new ViewRegistry
    @paneContainer ?= new PaneContainer({@viewRegistry})
    @paneContainer.onDidDestroyPaneItem(@onPaneItemDestroyed)

    @panelContainers =
      top: new PanelContainer({@viewRegistry, location: 'top'})
      left: new PanelContainer({@viewRegistry, location: 'left'})
      right: new PanelContainer({@viewRegistry, location: 'right'})
      bottom: new PanelContainer({@viewRegistry, location: 'bottom'})

    @subscribeToActiveItem()

    @addOpener (filePath) =>
      switch filePath
        when 'atom://.atom/stylesheet'
          @open(atom.themes.getUserStylesheetPath())
        when 'atom://.atom/keymap'
          @open(atom.keymaps.getUserKeymapPath())
        when 'atom://.atom/config'
          @open(atom.config.getUserConfigPath())
        when 'atom://.atom/init-script'
          @open(atom.getUserInitScriptPath())

    @addViewProvider
      modelConstructor: Workspace
      viewConstructor: WorkspaceElement

    @addViewProvider
      modelConstructor: PanelContainer
      viewConstructor: PanelContainerElement

    @addViewProvider
      modelConstructor: Panel
      viewConstructor: PanelElement

  # Called by the Serializable mixin during deserialization
  deserializeParams: (params) ->
    for packageName in params.packagesWithActiveGrammars ? []
      atom.packages.getLoadedPackage(packageName)?.loadGrammarsSync()

    params.viewRegistry = new ViewRegistry
    params.paneContainer.viewRegistry = params.viewRegistry
    params.paneContainer = PaneContainer.deserialize(params.paneContainer)
    params

  # Called by the Serializable mixin during serialization.
  serializeParams: ->
    paneContainer: @paneContainer.serialize()
    fullScreen: atom.isFullScreen()
    packagesWithActiveGrammars: @getPackageNamesWithActiveGrammars()

  getPackageNamesWithActiveGrammars: ->
    packageNames = []
    addGrammar = ({includedGrammarScopes, packageName}={}) ->
      return unless packageName
      # Prevent cycles
      return if packageNames.indexOf(packageName) isnt -1

      packageNames.push(packageName)
      for scopeName in includedGrammarScopes ? []
        addGrammar(atom.syntax.grammarForScopeName(scopeName))

    editors = @getTextEditors()
    addGrammar(editor.getGrammar()) for editor in editors

    if editors.length > 0
      for grammar in atom.syntax.getGrammars() when grammar.injectionSelector
        addGrammar(grammar)

    _.uniq(packageNames)

  editorAdded: (editor) ->
    @emit 'editor-created', editor

  installShellCommands: ->
    require('./command-installer').installShellCommandsInteractively()

  subscribeToActiveItem: ->
    @updateWindowTitle()
    @updateDocumentEdited()
    atom.project.onDidChangePaths @updateWindowTitle

    @observeActivePaneItem (item) =>
      @updateWindowTitle()
      @updateDocumentEdited()

      @activeItemSubscriptions?.dispose()
      @activeItemSubscriptions = new CompositeDisposable

      if typeof item?.onDidChangeTitle is 'function'
        titleSubscription = item.onDidChangeTitle(@updateWindowTitle)
      else if typeof item?.on is 'function'
        titleSubscription = item.on('title-changed', @updateWindowTitle)
        unless typeof titleSubscription?.dispose is 'function'
          titleSubscription = new Disposable => item.off('title-changed', @updateWindowTitle)

      if typeof item?.onDidChangeModified is 'function'
        modifiedSubscription = item.onDidChangeModified(@updateDocumentEdited)
      else if typeof item?.on? is 'function'
        modifiedSubscription = item.on('modified-status-changed', @updateDocumentEdited)
        unless typeof modifiedSubscription?.dispose is 'function'
          modifiedSubscription = new Disposable => item.off('modified-status-changed', @updateDocumentEdited)

      @activeItemSubscriptions.add(titleSubscription) if titleSubscription?
      @activeItemSubscriptions.add(modifiedSubscription) if modifiedSubscription?

  # Updates the application's title and proxy icon based on whichever file is
  # open.
  updateWindowTitle: =>
    appName = 'Atom'
    if projectPath = atom.project?.getPaths()[0]
      if item = @getActivePaneItem()
        document.title = "#{item.getTitle?() ? 'untitled'} - #{projectPath} - #{appName}"
        atom.setRepresentedFilename(item.getPath?() ? projectPath)
      else
        document.title = "#{projectPath} - #{appName}"
        atom.setRepresentedFilename(projectPath)
    else
      document.title = "untitled - #{appName}"
      atom.setRepresentedFilename('')

  # On OS X, fades the application window's proxy icon when the current file
  # has been modified.
  updateDocumentEdited: =>
    modified = @getActivePaneItem()?.isModified?() ? false
    atom.setDocumentEdited(modified)

  ###
  Section: Event Subscription
  ###

  # Essential: Invoke the given callback with all current and future text
  # editors in the workspace.
  #
  # * `callback` {Function} to be called with current and future text editors.
  #   * `editor` An {TextEditor} that is present in {::getTextEditors} at the time
  #     of subscription or that is added at some later time.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observeTextEditors: (callback) ->
    callback(textEditor) for textEditor in @getTextEditors()
    @onDidAddTextEditor ({textEditor}) -> callback(textEditor)

  # Essential: Invoke the given callback with all current and future panes items
  # in the workspace.
  #
  # * `callback` {Function} to be called with current and future pane items.
  #   * `item` An item that is present in {::getPaneItems} at the time of
  #      subscription or that is added at some later time.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observePaneItems: (callback) -> @paneContainer.observePaneItems(callback)

  # Essential: Invoke the given callback when the active pane item changes.
  #
  # * `callback` {Function} to be called when the active pane item changes.
  #   * `event` {Object} with the following keys:
  #     * `activeItem` The active pane item.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeActivePaneItem: (callback) -> @paneContainer.onDidChangeActivePaneItem(callback)

  # Essential: Invoke the given callback with the current active pane item and
  # with all future active pane items in the workspace.
  #
  # * `callback` {Function} to be called when the active pane item changes.
  #   * `item` The current active pane item.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observeActivePaneItem: (callback) -> @paneContainer.observeActivePaneItem(callback)

  # Essential: Invoke the given callback whenever an item is opened. Unlike
  # {::onDidAddPaneItem}, observers will be notified for items that are already
  # present in the workspace when they are reopened.
  #
  # * `callback` {Function} to be called whenever an item is opened.
  #   * `event` {Object} with the following keys:
  #     * `uri` {String} representing the opened URI. Could be `undefined`.
  #     * `item` The opened item.
  #     * `pane` The pane in which the item was opened.
  #     * `index` The index of the opened item on its pane.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidOpen: (callback) ->
    @emitter.on 'did-open', callback

  # Extended: Invoke the given callback when a pane is added to the workspace.
  #
  # * `callback` {Function} to be called panes are added.
  #   * `event` {Object} with the following keys:
  #     * `pane` The added pane.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidAddPane: (callback) -> @paneContainer.onDidAddPane(callback)

  # Extended: Invoke the given callback with all current and future panes in the
  # workspace.
  #
  # * `callback` {Function} to be called with current and future panes.
  #   * `pane` A {Pane} that is present in {::getPanes} at the time of
  #      subscription or that is added at some later time.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observePanes: (callback) -> @paneContainer.observePanes(callback)

  # Extended: Invoke the given callback when the active pane changes.
  #
  # * `callback` {Function} to be called when the active pane changes.
  #   * `pane` A {Pane} that is the current return value of {::getActivePane}.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeActivePane: (callback) -> @paneContainer.onDidChangeActivePane(callback)

  # Extended: Invoke the given callback with the current active pane and when
  # the active pane changes.
  #
  # * `callback` {Function} to be called with the current and future active#
  #   panes.
  #   * `pane` A {Pane} that is the current return value of {::getActivePane}.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observeActivePane: (callback) -> @paneContainer.observeActivePane(callback)

  # Extended: Invoke the given callback when a pane item is added to the
  # workspace.
  #
  # * `callback` {Function} to be called when panes are added.
  #   * `event` {Object} with the following keys:
  #     * `item` The added pane item.
  #     * `pane` {Pane} containing the added item.
  #     * `index` {Number} indicating the index of the added item in its pane.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidAddPaneItem: (callback) -> @paneContainer.onDidAddPaneItem(callback)

  # Extended: Invoke the given callback when a text editor is added to the
  # workspace.
  #
  # * `callback` {Function} to be called panes are added.
  #   * `event` {Object} with the following keys:
  #     * `textEditor` {TextEditor} that was added.
  #     * `pane` {Pane} containing the added text editor.
  #     * `index` {Number} indicating the index of the added text editor in its
  #        pane.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidAddTextEditor: (callback) ->
    @onDidAddPaneItem ({item, pane, index}) ->
      callback({textEditor: item, pane, index}) if item instanceof TextEditor

  eachEditor: (callback) ->
    deprecate("Use Workspace::observeTextEditors instead")

    callback(editor) for editor in @getEditors()
    @subscribe this, 'editor-created', (editor) -> callback(editor)

  getEditors: ->
    deprecate("Use Workspace::getTextEditors instead")

    editors = []
    for pane in @paneContainer.getPanes()
      editors.push(item) for item in pane.getItems() when item instanceof TextEditor

    editors

  on: (eventName) ->
    switch eventName
      when 'editor-created'
        deprecate("Use Workspace::onDidAddTextEditor or Workspace::observeTextEditors instead.")
      when 'uri-opened'
        deprecate("Use Workspace::onDidAddPaneItem instead.")
      else
        deprecate("Subscribing via ::on is deprecated. Use documented event subscription methods instead.")

    super

  ###
  Section: Opening
  ###

  # Essential: Open a given a URI in Atom asynchronously.
  #
  # * `uri` A {String} containing a URI.
  # * `options` (optional) {Object}
  #   * `initialLine` A {Number} indicating which row to move the cursor to
  #     initially. Defaults to `0`.
  #   * `initialColumn` A {Number} indicating which column to move the cursor to
  #     initially. Defaults to `0`.
  #   * `split` Either 'left' or 'right'. If 'left', the item will be opened in
  #     leftmost pane of the current active pane's row. If 'right', the
  #     item will be opened in the rightmost pane of the current active pane's row.
  #   * `activatePane` A {Boolean} indicating whether to call {Pane::activate} on
  #     containing pane. Defaults to `true`.
  #   * `searchAllPanes` A {Boolean}. If `true`, the workspace will attempt to
  #     activate an existing item for the given URI on any pane.
  #     If `false`, only the active pane will be searched for
  #     an existing item for the same URI. Defaults to `false`.
  #
  # Returns a promise that resolves to the {TextEditor} for the file URI.
  open: (uri, options={}) ->
    searchAllPanes = options.searchAllPanes
    split = options.split
    uri = atom.project.resolve(uri)

    pane = @paneContainer.paneForUri(uri) if searchAllPanes
    pane ?= switch split
      when 'left'
        @getActivePane().findLeftmostSibling()
      when 'right'
        @getActivePane().findOrCreateRightmostSibling()
      else
        @getActivePane()

    @openUriInPane(uri, pane, options)

  # Open Atom's license in the active pane.
  openLicense: ->
    @open(join(atom.getLoadSettings().resourcePath, 'LICENSE.md'))

  # Synchronously open the given URI in the active pane. **Only use this method
  # in specs. Calling this in production code will block the UI thread and
  # everyone will be mad at you.**
  #
  # * `uri` A {String} containing a URI.
  # * `options` An optional options {Object}
  #   * `initialLine` A {Number} indicating which row to move the cursor to
  #     initially. Defaults to `0`.
  #   * `initialColumn` A {Number} indicating which column to move the cursor to
  #     initially. Defaults to `0`.
  #   * `activatePane` A {Boolean} indicating whether to call {Pane::activate} on
  #     the containing pane. Defaults to `true`.
  openSync: (uri='', options={}) ->
    deprecate("Don't use the `changeFocus` option") if options.changeFocus?

    {initialLine, initialColumn} = options
    # TODO: Remove deprecated changeFocus option
    activatePane = options.activatePane ? options.changeFocus ? true
    uri = atom.project.resolve(uri)

    item = @activePane.itemForUri(uri)
    if uri
      item ?= opener(uri, options) for opener in @getOpeners() when !item
    item ?= atom.project.openSync(uri, {initialLine, initialColumn})

    @activePane.activateItem(item)
    @itemOpened(item)
    @activePane.activate() if activatePane
    item

  openUriInPane: (uri, pane, options={}) ->
    changeFocus = options.changeFocus ? true

    if uri?
      item = pane.itemForUri(uri)
      item ?= opener(atom.project.resolve(uri), options) for opener in @getOpeners() when !item
    item ?= atom.project.open(uri, options)

    Q(item)
      .then (item) =>
        if not pane
          pane = new Pane(items: [item])
          @paneContainer.root = pane
        @itemOpened(item)
        pane.activateItem(item)
        pane.activate() if changeFocus
        index = pane.getActiveItemIndex()
        @emit "uri-opened"
        @emitter.emit 'did-open', {uri, pane, item, index}
        item
      .catch (error) ->
        console.error(error.stack ? error)

  # Public: Asynchronously reopens the last-closed item's URI if it hasn't already been
  # reopened.
  #
  # Returns a promise that is resolved when the item is opened
  reopenItem: ->
    if uri = @destroyedItemUris.pop()
      @open(uri)
    else
      Q()

  # Deprecated
  reopenItemSync: ->
    deprecate("Use Workspace::reopenItem instead")
    if uri = @destroyedItemUris.pop()
      @openSync(uri)

  # Public: Register an opener for a uri.
  #
  # An {TextEditor} will be used if no openers return a value.
  #
  # ## Examples
  #
  # ```coffee
  # atom.project.addOpener (uri) ->
  #   if path.extname(uri) is '.toml'
  #     return new TomlEditor(uri)
  # ```
  #
  # * `opener` A {Function} to be called when a path is being opened.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to remove the
  # opener.
  addOpener: (opener) ->
    @openers.push(opener)
    new Disposable => _.remove(@openers, opener)
  registerOpener: (opener) ->
    Grim.deprecate("Call Workspace::addOpener instead")
    @addOpener(opener)

  unregisterOpener: (opener) ->
    Grim.deprecate("Call .dispose() on the Disposable returned from ::addOpener instead")
    _.remove(@openers, opener)

  getOpeners: ->
    @openers

  ###
  Section: Pane Items
  ###

  # Essential: Get all pane items in the workspace.
  #
  # Returns an {Array} of items.
  getPaneItems: ->
    @paneContainer.getPaneItems()

  # Essential: Get the active {Pane}'s active item.
  #
  # Returns an pane item {Object}.
  getActivePaneItem: ->
    @paneContainer.getActivePaneItem()

  # Essential: Get all text editors in the workspace.
  #
  # Returns an {Array} of {TextEditor}s.
  getTextEditors: ->
    @getPaneItems().filter (item) -> item instanceof TextEditor

  # Essential: Get the active item if it is an {TextEditor}.
  #
  # Returns an {TextEditor} or `undefined` if the current active item is not an
  # {TextEditor}.
  getActiveTextEditor: ->
    activeItem = @getActivePaneItem()
    activeItem if activeItem instanceof TextEditor

  # Deprecated:
  getActiveEditor: ->
    @activePane?.getActiveEditor()

  # Save all pane items.
  saveAll: ->
    @paneContainer.saveAll()

  confirmClose: ->
    @paneContainer.confirmClose()

  # Save the active pane item.
  #
  # If the active pane item currently has a URI according to the item's
  # `.getUri` method, calls `.save` on the item. Otherwise
  # {::saveActivePaneItemAs} # will be called instead. This method does nothing
  # if the active item does not implement a `.save` method.
  saveActivePaneItem: ->
    @activePane?.saveActiveItem()

  # Prompt the user for a path and save the active pane item to it.
  #
  # Opens a native dialog where the user selects a path on disk, then calls
  # `.saveAs` on the item with the selected path. This method does nothing if
  # the active item does not implement a `.saveAs` method.
  saveActivePaneItemAs: ->
    @activePane?.saveActiveItemAs()

  # Destroy (close) the active pane item.
  #
  # Removes the active pane item and calls the `.destroy` method on it if one is
  # defined.
  destroyActivePaneItem: ->
    @activePane?.destroyActiveItem()

  ###
  Section: Panes
  ###

  # Extended: Get all panes in the workspace.
  #
  # Returns an {Array} of {Pane}s.
  getPanes: ->
    @paneContainer.getPanes()

  # Extended: Get the active {Pane}.
  #
  # Returns a {Pane}.
  getActivePane: ->
    @paneContainer.getActivePane()

  # Extended: Make the next pane active.
  activateNextPane: ->
    @paneContainer.activateNextPane()

  # Extended: Make the previous pane active.
  activatePreviousPane: ->
    @paneContainer.activatePreviousPane()

  # Extended: Get the first pane {Pane} with an item for the given URI.
  #
  # * `uri` {String} uri
  #
  # Returns a {Pane} or `undefined` if no pane exists for the given URI.
  paneForUri: (uri) ->
    @paneContainer.paneForUri(uri)

  # Destroy (close) the active pane.
  destroyActivePane: ->
    @activePane?.destroy()

  # Destroy the active pane item or the active pane if it is empty.
  destroyActivePaneItemOrEmptyPane: ->
    if @getActivePaneItem()? then @destroyActivePaneItem() else @destroyActivePane()

  # Increase the editor font size by 1px.
  increaseFontSize: ->
    atom.config.set("editor.fontSize", atom.config.get("editor.fontSize") + 1)

  # Decrease the editor font size by 1px.
  decreaseFontSize: ->
    fontSize = atom.config.get("editor.fontSize")
    atom.config.set("editor.fontSize", fontSize - 1) if fontSize > 1

  # Restore to a default editor font size.
  resetFontSize: ->
    atom.config.restoreDefault("editor.fontSize")

  # Removes the item's uri from the list of potential items to reopen.
  itemOpened: (item) ->
    if uri = item.getUri?()
      _.remove(@destroyedItemUris, uri)

  # Adds the destroyed item's uri to the list of items to reopen.
  onPaneItemDestroyed: (item) =>
    if uri = item.getUri?()
      @destroyedItemUris.push(uri)

  # Called by Model superclass when destroyed
  destroyed: ->
    @paneContainer.destroy()
    @activeItemSubscriptions?.dispose()


  ###
  Section: Panels
  ###

  # Essential: Adds a panel item to the bottom of the editor window.
  #
  # * `options` {Object}
  #   * `item` Your panel content. It can be DOM element, a jQuery element, or
  #     a model with a view registered via {::addViewProvider}. We recommend the
  #     latter. See {::addViewProvider} for more information.
  #   * `visible` (optional) {Boolean} false if you want the panel to initially be hidden
  #     (default: true)
  #   * `priority` (optional) {Number} Determines stacking order. Lower priority items are
  #     forced closer to the edges of the window. (default: 100)
  #
  # Returns a {Panel}
  addBottomPanel: (options) ->
    @addPanel('bottom', options)

  # Essential: Adds a panel item to the left of the editor window.
  #
  # * `options` {Object}
  #   * `item` Your panel content. It can be DOM element, a jQuery element, or
  #     a model with a view registered via {::addViewProvider}. We recommend the
  #     latter. See {::addViewProvider} for more information.
  #   * `visible` (optional) {Boolean} false if you want the panel to initially be hidden
  #     (default: true)
  #   * `priority` (optional) {Number} Determines stacking order. Lower priority items are
  #     forced closer to the edges of the window. (default: 100)
  #
  # Returns a {Panel}
  addLeftPanel: (options) ->
    @addPanel('left', options)

  # Essential: Adds a panel item to the right of the editor window.
  #
  # * `options` {Object}
  #   * `item` Your panel content. It can be DOM element, a jQuery element, or
  #     a model with a view registered via {::addViewProvider}. We recommend the
  #     latter. See {::addViewProvider} for more information.
  #   * `visible` (optional) {Boolean} false if you want the panel to initially be hidden
  #     (default: true)
  #   * `priority` (optional) {Number} Determines stacking order. Lower priority items are
  #     forced closer to the edges of the window. (default: 100)
  #
  # Returns a {Panel}
  addRightPanel: (options) ->
    @addPanel('right', options)

  # Essential: Adds a panel item to the top of the editor window above the tabs.
  #
  # * `options` {Object}
  #   * `item` Your panel content. It can be DOM element, a jQuery element, or
  #     a model with a view registered via {::addViewProvider}. We recommend the
  #     latter. See {::addViewProvider} for more information.
  #   * `visible` (optional) {Boolean} false if you want the panel to initially be hidden
  #     (default: true)
  #   * `priority` (optional) {Number} Determines stacking order. Lower priority items are
  #     forced closer to the edges of the window. (default: 100)
  #
  # Returns a {Panel}
  addTopPanel: (options) ->
    @addPanel('top', options)

  addPanel: (location, options) ->
    options ?= {}
    options.viewRegistry = @viewRegistry
    @panelContainers[location].addPanel(new Panel(options))

  ###
  Section: View Management
  ###

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
  # textEditorView = atom.workspace.getView(textEditor)
  # ```
  #
  # ### Getting A Pane View
  # ```coffee
  # pane = atom.workspace.getActivePane()
  # paneView = atom.workspace.getView(pane)
  # ```
  #
  # ### Getting The Workspace View
  #
  # ```coffee
  # workspaceView = atom.workspace.getView(atom.workspace)
  # ```
  #
  # * `object` The object for which you want to retrieve a view. This can be a
  #   pane item, a pane, or the workspace itself.
  #
  # Returns a DOM element.
  getView: (object) ->
    @viewRegistry.getView(object)

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
  # atom.workspace.addViewProvider
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
    @viewRegistry.addViewProvider(providerSpec)
