{includeDeprecatedAPIs, deprecate} = require 'grim'
_ = require 'underscore-plus'
path = require 'path'
{join} = path
Q = require 'q'
Serializable = require 'serializable'
{Emitter, Disposable, CompositeDisposable} = require 'event-kit'
Grim = require 'grim'
fs = require 'fs-plus'
DefaultDirectorySearcher = require './default-directory-searcher'
Model = require './model'
TextEditor = require './text-editor'
PaneContainer = require './pane-container'
Pane = require './pane'
Panel = require './panel'
PanelElement = require './panel-element'
PanelContainer = require './panel-container'
PanelContainerElement = require './panel-container-element'
WorkspaceElement = require './workspace-element'
Task = require './task'

# Essential: Represents the state of the user interface for the entire window.
# An instance of this class is available via the `atom.workspace` global.
#
# Interact with this object to open files, be notified of current and future
# editors, and manipulate panes. To add panels, use {Workspace::addTopPanel}
# and friends.
#
# * `editor` {TextEditor} the new editor
#
module.exports =
class Workspace extends Model
  atom.deserializers.add(this)
  Serializable.includeInto(this)

  constructor: (params) ->
    super

    unless Grim.includeDeprecatedAPIs
      @paneContainer = params?.paneContainer
      @fullScreen = params?.fullScreen ? false
      @destroyedItemURIs = params?.destroyedItemURIs ? []

    @emitter = new Emitter
    @openers = []

    @paneContainer ?= new PaneContainer()
    @paneContainer.onDidDestroyPaneItem(@didDestroyPaneItem)

    @directorySearchers = []
    @defaultDirectorySearcher = new DefaultDirectorySearcher()
    atom.packages.serviceHub.consume(
      'atom.directory-searcher',
      '^0.1.0',
      (provider) => @directorySearchers.unshift(provider))

    @panelContainers =
      top: new PanelContainer({location: 'top'})
      left: new PanelContainer({location: 'left'})
      right: new PanelContainer({location: 'right'})
      bottom: new PanelContainer({location: 'bottom'})
      modal: new PanelContainer({location: 'modal'})

    @subscribeToActiveItem()

    @addOpener (filePath) ->
      switch filePath
        when 'atom://.atom/stylesheet'
          atom.project.open(atom.styles.getUserStyleSheetPath())
        when 'atom://.atom/keymap'
          atom.project.open(atom.keymaps.getUserKeymapPath())
        when 'atom://.atom/config'
          atom.project.open(atom.config.getUserConfigPath())
        when 'atom://.atom/init-script'
          atom.project.open(atom.getUserInitScriptPath())

    atom.views.addViewProvider Workspace, (model) ->
      new WorkspaceElement().initialize(model)

    atom.views.addViewProvider PanelContainer, (model) ->
      new PanelContainerElement().initialize(model)

    atom.views.addViewProvider Panel, (model) ->
      new PanelElement().initialize(model)

    @subscribeToFontSize()

  # Called by the Serializable mixin during deserialization
  deserializeParams: (params) ->
    for packageName in params.packagesWithActiveGrammars ? []
      atom.packages.getLoadedPackage(packageName)?.loadGrammarsSync()

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
        addGrammar(atom.grammars.grammarForScopeName(scopeName))
      return

    editors = @getTextEditors()
    addGrammar(editor.getGrammar()) for editor in editors

    if editors.length > 0
      for grammar in atom.grammars.getGrammars() when grammar.injectionSelector
        addGrammar(grammar)

    _.uniq(packageNames)

  editorAdded: (editor) ->
    @emit 'editor-created', editor if includeDeprecatedAPIs

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
    projectPaths = atom.project?.getPaths() ? []
    if item = @getActivePaneItem()
      itemPath = item.getPath?()
      itemTitle = item.getTitle?()
      projectPath = _.find projectPaths, (projectPath) ->
        itemPath is projectPath or itemPath?.startsWith(projectPath + path.sep)
    itemTitle ?= "untitled"
    projectPath ?= projectPaths[0]

    if item? and projectPath?
      document.title = "#{itemTitle} - #{projectPath} - #{appName}"
      atom.setRepresentedFilename(itemPath ? projectPath)
    else if projectPath?
      document.title = "#{projectPath} - #{appName}"
      atom.setRepresentedFilename(projectPath)
    else
      document.title = "#{itemTitle} - #{appName}"
      atom.setRepresentedFilename("")

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
  #   * `item` The active pane item.
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

  # Extended: Invoke the given callback before a pane is destroyed in the
  # workspace.
  #
  # * `callback` {Function} to be called before panes are destroyed.
  #   * `event` {Object} with the following keys:
  #     * `pane` The pane to be destroyed.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onWillDestroyPane: (callback) -> @paneContainer.onWillDestroyPane(callback)

  # Extended: Invoke the given callback when a pane is destroyed in the
  # workspace.
  #
  # * `callback` {Function} to be called panes are destroyed.
  #   * `event` {Object} with the following keys:
  #     * `pane` The destroyed pane.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDestroyPane: (callback) -> @paneContainer.onDidDestroyPane(callback)

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
  # * `callback` {Function} to be called when pane items are added.
  #   * `event` {Object} with the following keys:
  #     * `item` The added pane item.
  #     * `pane` {Pane} containing the added item.
  #     * `index` {Number} indicating the index of the added item in its pane.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidAddPaneItem: (callback) -> @paneContainer.onDidAddPaneItem(callback)

  # Extended: Invoke the given callback when a pane item is about to be
  # destroyed, before the user is prompted to save it.
  #
  # * `callback` {Function} to be called before pane items are destroyed.
  #   * `event` {Object} with the following keys:
  #     * `item` The item to be destroyed.
  #     * `pane` {Pane} containing the item to be destroyed.
  #     * `index` {Number} indicating the index of the item to be destroyed in
  #       its pane.
  #
  # Returns a {Disposable} on which `.dispose` can be called to unsubscribe.
  onWillDestroyPaneItem: (callback) -> @paneContainer.onWillDestroyPaneItem(callback)

  # Extended: Invoke the given callback when a pane item is destroyed.
  #
  # * `callback` {Function} to be called when pane items are destroyed.
  #   * `event` {Object} with the following keys:
  #     * `item` The destroyed item.
  #     * `pane` {Pane} containing the destroyed item.
  #     * `index` {Number} indicating the index of the destroyed item in its
  #       pane.
  #
  # Returns a {Disposable} on which `.dispose` can be called to unsubscribe.
  onDidDestroyPaneItem: (callback) -> @paneContainer.onDidDestroyPaneItem(callback)

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

  ###
  Section: Opening
  ###

  # Essential: Opens the given URI in Atom asynchronously.
  # If the URI is already open, the existing item for that URI will be
  # activated. If no URI is given, or no registered opener can open
  # the URI, a new empty {TextEditor} will be created.
  #
  # * `uri` (optional) A {String} containing a URI.
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
    uri = atom.project.resolvePath(uri)

    pane = @paneContainer.paneForURI(uri) if searchAllPanes
    pane ?= switch split
      when 'left'
        @getActivePane().findLeftmostSibling()
      when 'right'
        @getActivePane().findOrCreateRightmostSibling()
      else
        @getActivePane()

    @openURIInPane(uri, pane, options)

  # Open Atom's license in the active pane.
  openLicense: ->
    @open(path.join(process.resourcesPath, 'LICENSE.md'))

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
    # TODO: Remove deprecated changeFocus option
    if includeDeprecatedAPIs and options.changeFocus?
      deprecate("The `changeFocus` option has been renamed to `activatePane`")
      options.activatePane = options.changeFocus
      delete options.changeFocus

    {initialLine, initialColumn} = options
    activatePane = options.activatePane ? true

    uri = atom.project.resolvePath(uri)
    item = @getActivePane().itemForURI(uri)
    if uri
      item ?= opener(uri, options) for opener in @getOpeners() when not item
    item ?= atom.project.openSync(uri, {initialLine, initialColumn})

    @getActivePane().activateItem(item)
    @itemOpened(item)
    @getActivePane().activate() if activatePane
    item

  openURIInPane: (uri, pane, options={}) ->
    # TODO: Remove deprecated changeFocus option
    if includeDeprecatedAPIs and options.changeFocus?
      deprecate("The `changeFocus` option has been renamed to `activatePane`")
      options.activatePane = options.changeFocus
      delete options.changeFocus

    activatePane = options.activatePane ? true

    if uri?
      item = pane.itemForURI(uri)
      item ?= opener(uri, options) for opener in @getOpeners() when not item

    try
      item ?= atom.project.open(uri, options)
    catch error
      switch error.code
        when 'CANCELLED'
          return Q()
        when 'EACCES'
          atom.notifications.addWarning("Permission denied '#{error.path}'")
          return Q()
        when 'EPERM', 'EBUSY', 'ENXIO', 'EIO', 'ENOTCONN', 'UNKNOWN', 'ECONNRESET', 'EINVAL'
          atom.notifications.addWarning("Unable to open '#{error.path ? uri}'", detail: error.message)
          return Q()
        else
          throw error

    Q(item)
      .then (item) =>
        if not pane
          pane = new Pane(items: [item])
          @paneContainer.root = pane
        @itemOpened(item)
        pane.activateItem(item)
        pane.activate() if activatePane

        initialLine = initialColumn = 0
        unless Number.isNaN(options.initialLine)
          initialLine = options.initialLine
        unless Number.isNaN(options.initialColumn)
          initialColumn = options.initialColumn
        if initialLine >= 0 or initialColumn >= 0
          item.setCursorBufferPosition?([initialLine, initialColumn])

        index = pane.getActiveItemIndex()
        @emit "uri-opened" if includeDeprecatedAPIs
        @emitter.emit 'did-open', {uri, pane, item, index}
        item

  # Public: Asynchronously reopens the last-closed item's URI if it hasn't already been
  # reopened.
  #
  # Returns a promise that is resolved when the item is opened
  reopenItem: ->
    if uri = @destroyedItemURIs.pop()
      @open(uri)
    else
      Q()

  # Public: Register an opener for a uri.
  #
  # An {TextEditor} will be used if no openers return a value.
  #
  # ## Examples
  #
  # ```coffee
  # atom.workspace.addOpener (uri) ->
  #   if path.extname(uri) is '.toml'
  #     return new TomlEditor(uri)
  # ```
  #
  # * `opener` A {Function} to be called when a path is being opened.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to remove the
  # opener.
  #
  # Note that the opener will be called if and only if the URI is not already open
  # in the current pane. The searchAllPanes flag expands the search from the
  # current pane to all panes. If you wish to open a view of a different type for
  # a file that is already open, consider changing the protocol of the URI. For
  # example, perhaps you wish to preview a rendered version of the file `/foo/bar/baz.quux`
  # that is already open in a text editor view. You could signal this by calling
  # {Workspace::open} on the URI `quux-preview://foo/bar/baz.quux`. Then your opener
  # can check the protocol for quux-preview and only handle those URIs that match.
  addOpener: (opener) ->
    if includeDeprecatedAPIs
      packageName = @getCallingPackageName()

      wrappedOpener = (uri, options) ->
        item = opener(uri, options)
        if item? and typeof item.getUri is 'function' and typeof item.getURI isnt 'function'
          Grim.deprecate("Pane item with class `#{item.constructor.name}` should implement `::getURI` instead of `::getUri`.", {packageName})
        if item? and typeof item.on is 'function' and typeof item.onDidChangeTitle isnt 'function'
          Grim.deprecate("If you would like your pane item with class `#{item.constructor.name}` to support title change behavior, please implement a `::onDidChangeTitle()` method. `::on` methods for items are no longer supported. If not, ignore this message.", {packageName})
        if item? and typeof item.on is 'function' and typeof item.onDidChangeModified isnt 'function'
          Grim.deprecate("If you would like your pane item with class `#{item.constructor.name}` to support modified behavior, please implement a `::onDidChangeModified()` method. If not, ignore this message. `::on` methods for items are no longer supported.", {packageName})
        item

      @openers.push(wrappedOpener)
      new Disposable => _.remove(@openers, wrappedOpener)
    else
      @openers.push(opener)
      new Disposable => _.remove(@openers, opener)

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

  # Save all pane items.
  saveAll: ->
    @paneContainer.saveAll()

  confirmClose: (options) ->
    @paneContainer.confirmClose(options)

  # Save the active pane item.
  #
  # If the active pane item currently has a URI according to the item's
  # `.getURI` method, calls `.save` on the item. Otherwise
  # {::saveActivePaneItemAs} # will be called instead. This method does nothing
  # if the active item does not implement a `.save` method.
  saveActivePaneItem: ->
    @getActivePane().saveActiveItem()

  # Prompt the user for a path and save the active pane item to it.
  #
  # Opens a native dialog where the user selects a path on disk, then calls
  # `.saveAs` on the item with the selected path. This method does nothing if
  # the active item does not implement a `.saveAs` method.
  saveActivePaneItemAs: ->
    @getActivePane().saveActiveItemAs()

  # Destroy (close) the active pane item.
  #
  # Removes the active pane item and calls the `.destroy` method on it if one is
  # defined.
  destroyActivePaneItem: ->
    @getActivePane().destroyActiveItem()

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

  # Extended: Get the first {Pane} with an item for the given URI.
  #
  # * `uri` {String} uri
  #
  # Returns a {Pane} or `undefined` if no pane exists for the given URI.
  paneForURI: (uri) ->
    @paneContainer.paneForURI(uri)

  # Extended: Get the {Pane} containing the given item.
  #
  # * `item` Item the returned pane contains.
  #
  # Returns a {Pane} or `undefined` if no pane exists for the given item.
  paneForItem: (item) ->
    @paneContainer.paneForItem(item)

  # Destroy (close) the active pane.
  destroyActivePane: ->
    @getActivePane()?.destroy()

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

  # Restore to the window's original editor font size.
  resetFontSize: ->
    if @originalFontSize
      atom.config.set("editor.fontSize", @originalFontSize)

  subscribeToFontSize: ->
    atom.config.onDidChange 'editor.fontSize', ({oldValue}) =>
      @originalFontSize ?= oldValue

  # Removes the item's uri from the list of potential items to reopen.
  itemOpened: (item) ->
    if typeof item.getURI is 'function'
      uri = item.getURI()
    else if typeof item.getUri is 'function'
      uri = item.getUri()

    if uri?
      _.remove(@destroyedItemURIs, uri)

  # Adds the destroyed item's uri to the list of items to reopen.
  didDestroyPaneItem: ({item}) =>
    if typeof item.getURI is 'function'
      uri = item.getURI()
    else if typeof item.getUri is 'function'
      uri = item.getUri()

    if uri?
      @destroyedItemURIs.push(uri)

  # Called by Model superclass when destroyed
  destroyed: ->
    @paneContainer.destroy()
    @activeItemSubscriptions?.dispose()


  ###
  Section: Panels

  Panels are used to display UI related to an editor window. They are placed at one of the four
  edges of the window: left, right, top or bottom. If there are multiple panels on the same window
  edge they are stacked in order of priority: higher priority is closer to the center, lower
  priority towards the edge.

  *Note:* If your panel changes its size throughout its lifetime, consider giving it a higher
  priority, allowing fixed size panels to be closer to the edge. This allows control targets to
  remain more static for easier targeting by users that employ mice or trackpads. (See
  [atom/atom#4834](https://github.com/atom/atom/issues/4834) for discussion.)
  ###

  # Essential: Get an {Array} of all the panel items at the bottom of the editor window.
  getBottomPanels: ->
    @getPanels('bottom')

  # Essential: Adds a panel item to the bottom of the editor window.
  #
  # * `options` {Object}
  #   * `item` Your panel content. It can be DOM element, a jQuery element, or
  #     a model with a view registered via {ViewRegistry::addViewProvider}. We recommend the
  #     latter. See {ViewRegistry::addViewProvider} for more information.
  #   * `visible` (optional) {Boolean} false if you want the panel to initially be hidden
  #     (default: true)
  #   * `priority` (optional) {Number} Determines stacking order. Lower priority items are
  #     forced closer to the edges of the window. (default: 100)
  #
  # Returns a {Panel}
  addBottomPanel: (options) ->
    @addPanel('bottom', options)

  # Essential: Get an {Array} of all the panel items to the left of the editor window.
  getLeftPanels: ->
    @getPanels('left')

  # Essential: Adds a panel item to the left of the editor window.
  #
  # * `options` {Object}
  #   * `item` Your panel content. It can be DOM element, a jQuery element, or
  #     a model with a view registered via {ViewRegistry::addViewProvider}. We recommend the
  #     latter. See {ViewRegistry::addViewProvider} for more information.
  #   * `visible` (optional) {Boolean} false if you want the panel to initially be hidden
  #     (default: true)
  #   * `priority` (optional) {Number} Determines stacking order. Lower priority items are
  #     forced closer to the edges of the window. (default: 100)
  #
  # Returns a {Panel}
  addLeftPanel: (options) ->
    @addPanel('left', options)

  # Essential: Get an {Array} of all the panel items to the right of the editor window.
  getRightPanels: ->
    @getPanels('right')

  # Essential: Adds a panel item to the right of the editor window.
  #
  # * `options` {Object}
  #   * `item` Your panel content. It can be DOM element, a jQuery element, or
  #     a model with a view registered via {ViewRegistry::addViewProvider}. We recommend the
  #     latter. See {ViewRegistry::addViewProvider} for more information.
  #   * `visible` (optional) {Boolean} false if you want the panel to initially be hidden
  #     (default: true)
  #   * `priority` (optional) {Number} Determines stacking order. Lower priority items are
  #     forced closer to the edges of the window. (default: 100)
  #
  # Returns a {Panel}
  addRightPanel: (options) ->
    @addPanel('right', options)

  # Essential: Get an {Array} of all the panel items at the top of the editor window.
  getTopPanels: ->
    @getPanels('top')

  # Essential: Adds a panel item to the top of the editor window above the tabs.
  #
  # * `options` {Object}
  #   * `item` Your panel content. It can be DOM element, a jQuery element, or
  #     a model with a view registered via {ViewRegistry::addViewProvider}. We recommend the
  #     latter. See {ViewRegistry::addViewProvider} for more information.
  #   * `visible` (optional) {Boolean} false if you want the panel to initially be hidden
  #     (default: true)
  #   * `priority` (optional) {Number} Determines stacking order. Lower priority items are
  #     forced closer to the edges of the window. (default: 100)
  #
  # Returns a {Panel}
  addTopPanel: (options) ->
    @addPanel('top', options)

  # Essential: Get an {Array} of all the modal panel items
  getModalPanels: ->
    @getPanels('modal')

  # Essential: Adds a panel item as a modal dialog.
  #
  # * `options` {Object}
  #   * `item` Your panel content. It can be a DOM element, a jQuery element, or
  #     a model with a view registered via {ViewRegistry::addViewProvider}. We recommend the
  #     model option. See {ViewRegistry::addViewProvider} for more information.
  #   * `visible` (optional) {Boolean} false if you want the panel to initially be hidden
  #     (default: true)
  #   * `priority` (optional) {Number} Determines stacking order. Lower priority items are
  #     forced closer to the edges of the window. (default: 100)
  #
  # Returns a {Panel}
  addModalPanel: (options={}) ->
    @addPanel('modal', options)

  # Essential: Returns the {Panel} associated with the given item. Returns
  # `null` when the item has no panel.
  #
  # * `item` Item the panel contains
  panelForItem: (item) ->
    for location, container of @panelContainers
      panel = container.panelForItem(item)
      return panel if panel?
    null

  getPanels: (location) ->
    @panelContainers[location].getPanels()

  addPanel: (location, options) ->
    options ?= {}
    @panelContainers[location].addPanel(new Panel(options))

  ###
  Section: Searching and Replacing
  ###

  # Public: Performs a search across all the files in the workspace.
  #
  # * `regex` {RegExp} to search with.
  # * `options` (optional) {Object} (default: {})
  #   * `paths` An {Array} of glob patterns to search within
  #   * `onPathsSearched` (optional) {Function}
  # * `iterator` {Function} callback on each file found
  #
  # Returns a `Promise` with a `cancel()` method that will cancel all
  # of the underlying searches that were started as part of this scan.
  scan: (regex, options={}, iterator) ->
    if _.isFunction(options)
      iterator = options
      options = {}

    # Find a searcher for every Directory in the project. Each searcher that is matched
    # will be associated with an Array of Directory objects in the Map.
    directoriesForSearcher = new Map()
    for directory in atom.project.getDirectories()
      searcher = @defaultDirectorySearcher
      for directorySearcher in @directorySearchers
        if directorySearcher.canSearchDirectory(directory)
          searcher = directorySearcher
          break
      directories = directoriesForSearcher.get(searcher)
      unless directories
        directories = []
        directoriesForSearcher.set(searcher, directories)
      directories.push(directory)

    # Define the onPathsSearched callback.
    if _.isFunction(options.onPathsSearched)
      # Maintain a map of directories to the number of search results. When notified of a new count,
      # replace the entry in the map and update the total.
      onPathsSearchedOption = options.onPathsSearched
      totalNumberOfPathsSearched = 0
      numberOfPathsSearchedForSearcher = new Map()
      onPathsSearched = (searcher, numberOfPathsSearched) ->
        oldValue = numberOfPathsSearchedForSearcher.get(searcher)
        if oldValue
          totalNumberOfPathsSearched -= oldValue
        numberOfPathsSearchedForSearcher.set(searcher, numberOfPathsSearched)
        totalNumberOfPathsSearched += numberOfPathsSearched
        onPathsSearchedOption(totalNumberOfPathsSearched)
    else
      onPathsSearched = ->

    # Kick off all of the searches and unify them into one Promise.
    allSearches = []
    directoriesForSearcher.forEach (directories, searcher) ->
      searchOptions =
        inclusions: options.paths or []
        includeHidden: true
        excludeVcsIgnores: atom.config.get('core.excludeVcsIgnoredPaths')
        exclusions: atom.config.get('core.ignoredNames')
        follow: atom.config.get('core.followSymlinks')
        didMatch: (result) ->
          iterator(result) unless atom.project.isPathModified(result.filePath)
        didError: (error) ->
          iterator(null, error)
        didSearchPaths: (count) -> onPathsSearched(searcher, count)
      directorySearcher = searcher.search(directories, regex, searchOptions)
      allSearches.push(directorySearcher)
    searchPromise = Promise.all(allSearches)

    for buffer in atom.project.getBuffers() when buffer.isModified()
      filePath = buffer.getPath()
      continue unless atom.project.contains(filePath)
      matches = []
      buffer.scan regex, (match) -> matches.push match
      iterator {filePath, matches} if matches.length > 0

    # Make sure the Promise that is returned to the client is cancelable. To be consistent
    # with the existing behavior, instead of cancel() rejecting the promise, it should
    # resolve it with the special value 'cancelled'. At least the built-in find-and-replace
    # package relies on this behavior.
    isCancelled = false
    cancellablePromise = new Promise (resolve, reject) ->
      onSuccess = ->
        if isCancelled
          resolve('cancelled')
        else
          resolve(null)
      searchPromise.then(onSuccess, reject)
    cancellablePromise.cancel = ->
      isCancelled = true
      # Note that cancelling all of the members of allSearches will cause all of the searches
      # to resolve, which causes searchPromise to resolve, which is ultimately what causes
      # cancellablePromise to resolve.
      promise.cancel() for promise in allSearches

    # Although this method claims to return a `Promise`, the `ResultsPaneView.onSearch()`
    # method in the find-and-replace package expects the object returned by this method to have a
    # `done()` method. Include a done() method until find-and-replace can be updated.
    cancellablePromise.done = (onSuccessOrFailure) ->
      cancellablePromise.then(onSuccessOrFailure, onSuccessOrFailure)
    cancellablePromise

  # Public: Performs a replace across all the specified files in the project.
  #
  # * `regex` A {RegExp} to search with.
  # * `replacementText` Text to replace all matches of regex with
  # * `filePaths` List of file path strings to run the replace on.
  # * `iterator` A {Function} callback on each file with replacements:
  #   * `options` {Object} with keys `filePath` and `replacements`
  #
  # Returns a `Promise`.
  replace: (regex, replacementText, filePaths, iterator) ->
    deferred = Q.defer()

    openPaths = (buffer.getPath() for buffer in atom.project.getBuffers())
    outOfProcessPaths = _.difference(filePaths, openPaths)

    inProcessFinished = not openPaths.length
    outOfProcessFinished = not outOfProcessPaths.length
    checkFinished = ->
      deferred.resolve() if outOfProcessFinished and inProcessFinished

    unless outOfProcessFinished.length
      flags = 'g'
      flags += 'i' if regex.ignoreCase

      task = Task.once require.resolve('./replace-handler'), outOfProcessPaths, regex.source, flags, replacementText, ->
        outOfProcessFinished = true
        checkFinished()

      task.on 'replace:path-replaced', iterator
      task.on 'replace:file-error', (error) -> iterator(null, error)

    for buffer in atom.project.getBuffers()
      continue unless buffer.getPath() in filePaths
      replacements = buffer.replace(regex, replacementText, iterator)
      iterator({filePath: buffer.getPath(), replacements}) if replacements

    inProcessFinished = true
    checkFinished()

    deferred.promise

if includeDeprecatedAPIs
  Workspace.properties
    paneContainer: null
    fullScreen: false
    destroyedItemURIs: -> []

  Object.defineProperty Workspace::, 'activePaneItem',
    get: ->
      Grim.deprecate "Use ::getActivePaneItem() instead of the ::activePaneItem property"
      @getActivePaneItem()

  Object.defineProperty Workspace::, 'activePane',
    get: ->
      Grim.deprecate "Use ::getActivePane() instead of the ::activePane property"
      @getActivePane()

  StackTraceParser = require 'stacktrace-parser'

  Workspace::getCallingPackageName = ->
    error = new Error
    Error.captureStackTrace(error)
    stack = StackTraceParser.parse(error.stack)

    packagePaths = @getPackagePathsByPackageName()

    for i in [0...stack.length]
      stackFramePath = stack[i].file

      # Empty when it was run from the dev console
      return unless stackFramePath

      for packageName, packagePath of packagePaths
        continue if stackFramePath is 'node.js'
        relativePath = path.relative(packagePath, stackFramePath)
        return packageName unless /^\.\./.test(relativePath)
    return

  Workspace::getPackagePathsByPackageName = ->
    packagePathsByPackageName = {}
    for pack in atom.packages.getLoadedPackages()
      packagePath = pack.path
      if packagePath.indexOf('.atom/dev/packages') > -1 or packagePath.indexOf('.atom/packages') > -1
        packagePath = fs.realpathSync(packagePath)
      packagePathsByPackageName[pack.name] = packagePath
    packagePathsByPackageName

  Workspace::eachEditor = (callback) ->
    deprecate("Use Workspace::observeTextEditors instead")

    callback(editor) for editor in @getEditors()
    @subscribe this, 'editor-created', (editor) -> callback(editor)

  Workspace::getEditors = ->
    deprecate("Use Workspace::getTextEditors instead")

    editors = []
    for pane in @paneContainer.getPanes()
      editors.push(item) for item in pane.getItems() when item instanceof TextEditor

    editors

  Workspace::on = (eventName) ->
    switch eventName
      when 'editor-created'
        deprecate("Use Workspace::onDidAddTextEditor or Workspace::observeTextEditors instead.")
      when 'uri-opened'
        deprecate("Use Workspace::onDidOpen or Workspace::onDidAddPaneItem instead. https://atom.io/docs/api/latest/Workspace#instance-onDidOpen")
      else
        deprecate("Subscribing via ::on is deprecated. Use documented event subscription methods instead.")

    super

  Workspace::reopenItemSync = ->
    deprecate("Use Workspace::reopenItem instead")
    if uri = @destroyedItemURIs.pop()
      @openSync(uri)

  Workspace::registerOpener = (opener) ->
    Grim.deprecate("Call Workspace::addOpener instead")
    @addOpener(opener)

  Workspace::unregisterOpener = (opener) ->
    Grim.deprecate("Call .dispose() on the Disposable returned from ::addOpener instead")
    _.remove(@openers, opener)

  Workspace::getActiveEditor = ->
    Grim.deprecate "Call ::getActiveTextEditor instead"
    @getActivePane()?.getActiveEditor()

  Workspace::paneForUri = (uri) ->
    deprecate("Use ::paneForURI instead.")
    @paneForURI(uri)
