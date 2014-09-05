{deprecate} = require 'grim'
_ = require 'underscore-plus'
{join} = require 'path'
{Model} = require 'theorist'
Q = require 'q'
Serializable = require 'serializable'
Delegator = require 'delegato'
{Emitter} = require 'event-kit'
Editor = require './editor'
PaneContainer = require './pane-container'
Pane = require './pane'

# Public: Represents the state of the user interface for the entire window.
# An instance of this class is available via the `atom.workspace` global.
#
# Interact with this object to open files, be notified of current and future
# editors, and manipulate panes. To add panels, you'll need to use the
# {WorkspaceView} class for now until we establish APIs at the model layer.
#
# * `editor` {Editor} the new editor
#
module.exports =
class Workspace extends Model
  atom.deserializers.add(this)
  Serializable.includeInto(this)

  @delegatesProperty 'activePane', 'activePaneItem', toProperty: 'paneContainer'

  @properties
    paneContainer: -> new PaneContainer
    fullScreen: false
    destroyedItemUris: -> []

  constructor: ->
    super

    @emitter = new Emitter
    @openers = []

    @paneContainer.onDidDestroyPaneItem(@onPaneItemDestroyed)

    @registerOpener (filePath) =>
      switch filePath
        when 'atom://.atom/stylesheet'
          @open(atom.themes.getUserStylesheetPath())
        when 'atom://.atom/keymap'
          @open(atom.keymaps.getUserKeymapPath())
        when 'atom://.atom/config'
          @open(atom.config.getUserConfigPath())
        when 'atom://.atom/init-script'
          @open(atom.getUserInitScriptPath())

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
        addGrammar(atom.syntax.grammarForScopeName(scopeName))

    editors = @getTextEditors()
    addGrammar(editor.getGrammar()) for editor in editors

    if editors.length > 0
      for grammar in atom.syntax.getGrammars() when grammar.injectionSelector
        addGrammar(grammar)

    _.uniq(packageNames)

  editorAdded: (editor) ->
    @emit 'editor-created', editor

  ###
  Section: Event Subscription
  ###

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

  # Extended: Invoke the given callback when a pane item is added to the
  # workspace.
  #
  # * `callback` {Function} to be called panes are added.
  #   * `event` {Object} with the following keys:
  #     * `item` The added pane item.
  #     * `pane` {Pane} containing the added item.
  #     * `index` {Number} indicating the index of the added item in its pane.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidAddPaneItem: (callback) -> @paneContainer.onDidAddPaneItem(callback)

  # Extended: Invoke the given callback with all current and future panes items in
  # the workspace.
  #
  # * `callback` {Function} to be called with current and future pane items.
  #   * `item` An item that is present in {::getPaneItems} at the time of
  #      subscription or that is added at some later time.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observePaneItems: (callback) -> @paneContainer.observePaneItems(callback)

  # Extended: Invoke the given callback when a text editor is added to the
  # workspace.
  #
  # * `callback` {Function} to be called panes are added.
  #   * `event` {Object} with the following keys:
  #     * `textEditor` {Editor} that was added.
  #     * `pane` {Pane} containing the added text editor.
  #     * `index` {Number} indicating the index of the added text editor in its
  #        pane.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidAddTextEditor: (callback) ->
    @onDidAddPaneItem ({item, pane, index}) ->
      callback({textEditor: item, pane, index}) if item instanceof Editor

  # Essential: Invoke the given callback with all current and future text
  # editors in the workspace.
  #
  # * `callback` {Function} to be called with current and future text editors.
  #   * `editor` An {Editor} that is present in {::getTextEditors} at the time
  #     of subscription or that is added at some later time.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observeTextEditors: (callback) ->
    callback(textEditor) for textEditor in @getTextEditors()
    @onDidAddTextEditor ({textEditor}) -> callback(textEditor)

  # Essential: Invoke the given callback whenever an item is opened. Unlike
  # ::onDidAddPaneItem, observers will be notified for items that are already
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

  eachEditor: (callback) ->
    deprecate("Use Workspace::observeTextEditors instead")

    callback(editor) for editor in @getEditors()
    @subscribe this, 'editor-created', (editor) -> callback(editor)

  getEditors: ->
    deprecate("Use Workspace::getTextEditors instead")

    editors = []
    for pane in @paneContainer.getPanes()
      editors.push(item) for item in pane.getItems() when item instanceof Editor

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
  # Returns a promise that resolves to the {Editor} for the file URI.
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

  # Extended: Asynchronously reopens the last-closed item's URI if it hasn't already been
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

  # Extended: Register an opener for a uri.
  #
  # An {Editor} will be used if no openers return a value.
  #
  # ## Examples
  #
  # ```coffee
  # atom.project.registerOpener (uri) ->
  #   if path.extname(uri) is '.toml'
  #     return new TomlEditor(uri)
  # ```
  #
  # * `opener` A {Function} to be called when a path is being opened.
  registerOpener: (opener) ->
    @openers.push(opener)

  # Extended: Unregister an opener registered with {::registerOpener}.
  unregisterOpener: (opener) ->
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
  # Returns an {Array} of {Editor}s.
  getTextEditors: ->
    @getPaneItems().filter (item) -> item instanceof Editor

  # Essential: Get the active item if it is an {Editor}.
  #
  # Returns an {Editor} or `undefined` if the current active item is not an
  # {Editor}.
  getActiveTextEditor: ->
    activeItem = @getActiveItem()
    activeItem if activeItem instanceof Editor

  # Deprecated:
  getActiveEditor: ->
    @activePane?.getActiveEditor()

  # Extended: Save all pane items.
  saveAll: ->
    @paneContainer.saveAll()

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
