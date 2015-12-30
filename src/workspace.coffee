{deprecate} = require 'grim'
_ = require 'underscore-plus'
{join} = require 'path'
{Model} = require 'theorist'
Q = require 'q'
Serializable = require 'serializable'
Delegator = require 'delegato'
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
# ## Events
#
# ### uri-opened
#
# Extended: Emit when something has been opened. This can be anything, from an
# editor to the settings view. You can get the new item via {::getActivePaneItem}
#
# ### editor-created
#
# Extended: Emit when an editor is created (a file opened).
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

    @openers = []

    @subscribe @paneContainer, 'item-destroyed', @onPaneItemDestroyed
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

    addGrammar(editor.getGrammar()) for editor in @getEditors()
    _.uniq(packageNames)

  editorAdded: (editor) ->
    @emit 'editor-created', editor

  # Public: Register a function to be called for every current and future
  # {Editor} in the workspace.
  #
  # * `callback` A {Function} with an {Editor} as its only argument.
  #
  # Returns a subscription object with an `.off` method that you can call to
  # unregister the callback.
  eachEditor: (callback) ->
    callback(editor) for editor in @getEditors()
    @subscribe this, 'editor-created', (editor) -> callback(editor)

  # Public: Get all current editors in the workspace.
  #
  # Returns an {Array} of {Editor}s.
  getEditors: ->
    editors = []
    for pane in @paneContainer.getPanes()
      editors.push(item) for item in pane.getItems() when item instanceof Editor

    editors

  # Public: Open a given a URI in Atom asynchronously.
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
        @activePane.findLeftmostSibling()
      when 'right'
        @activePane.findOrCreateRightmostSibling()
      else
        @activePane

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
        @emit "uri-opened"
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

  # Public: Unregister an opener registered with {::registerOpener}.
  unregisterOpener: (opener) ->
    _.remove(@openers, opener)

  getOpeners: ->
    @openers

  # Public: Get the active {Pane}.
  #
  # Returns a {Pane}.
  getActivePane: ->
    @paneContainer.activePane

  # Public: Get all {Pane}s.
  #
  # Returns an {Array} of {Pane}s.
  getPanes: ->
    @paneContainer.getPanes()

  # Public: Save all pane items.
  saveAll: ->
    @paneContainer.saveAll()

  # Public: Make the next pane active.
  activateNextPane: ->
    @paneContainer.activateNextPane()

  # Public: Make the previous pane active.
  activatePreviousPane: ->
    @paneContainer.activatePreviousPane()

  # Public: Get the first pane {Pane} with an item for the given URI.
  #
  # * `uri` {String} uri
  #
  # Returns a {Pane} or `undefined` if no pane exists for the given URI.
  paneForUri: (uri) ->
    @paneContainer.paneForUri(uri)

  # Public: Get the active {Pane}'s active item.
  #
  # Returns an pane item {Object}.
  getActivePaneItem: ->
    @paneContainer.getActivePane().getActiveItem()

  # Public: Save the active pane item.
  #
  # If the active pane item currently has a URI according to the item's
  # `.getUri` method, calls `.save` on the item. Otherwise
  # {::saveActivePaneItemAs} # will be called instead. This method does nothing
  # if the active item does not implement a `.save` method.
  saveActivePaneItem: ->
    @activePane?.saveActiveItem()

  # Public: Prompt the user for a path and save the active pane item to it.
  #
  # Opens a native dialog where the user selects a path on disk, then calls
  # `.saveAs` on the item with the selected path. This method does nothing if
  # the active item does not implement a `.saveAs` method.
  saveActivePaneItemAs: ->
    @activePane?.saveActiveItemAs()

  # Public: Destroy (close) the active pane item.
  #
  # Removes the active pane item and calls the `.destroy` method on it if one is
  # defined.
  destroyActivePaneItem: ->
    @activePane?.destroyActiveItem()

  # Public: Destroy (close) the active pane.
  destroyActivePane: ->
    @activePane?.destroy()

  # Public: Get the active item if it is an {Editor}.
  #
  # Returns an {Editor} or `undefined` if the current active item is not an
  # {Editor}.
  getActiveEditor: ->
    @activePane?.getActiveEditor()

  # Public: Increase the editor font size by 1px.
  increaseFontSize: ->
    atom.config.set("editor.fontSize", atom.config.get("editor.fontSize") + 1)

  # Public: Decrease the editor font size by 1px.
  decreaseFontSize: ->
    fontSize = atom.config.get("editor.fontSize")
    atom.config.set("editor.fontSize", fontSize - 1) if fontSize > 1

  # Public: Restore to a default editor font size.
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
