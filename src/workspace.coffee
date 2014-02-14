{remove, last} = require 'underscore-plus'
{Model} = require 'theorist'
Q = require 'q'
Serializable = require 'serializable'
Delegator = require 'delegato'
PaneContainer = require './pane-container'
Pane = require './pane'

# Public: Represents the view state of the entire window, including the panes at
# the center and panels around the periphery.
#
# An instance of this class is always available as the `atom.workspace` global.
module.exports =
class Workspace extends Model
  atom.deserializers.add(this)
  Serializable.includeInto(this)

  @delegatesProperty 'activePane', 'activePaneItem', toProperty: 'paneContainer'
  @delegatesMethod 'getPanes', 'saveAll', 'activateNextPane', 'activatePreviousPane',
    toProperty: 'paneContainer'

  @properties
    paneContainer: -> new PaneContainer
    fullScreen: false
    destroyedItemUris: -> []

  constructor: ->
    super
    @subscribe @paneContainer, 'item-destroyed', @onPaneItemDestroyed
    @registerOpener (filePath) =>
      switch filePath
        when 'atom://.atom/stylesheet'
          @open(atom.themes.getUserStylesheetPath())
        when 'atom://.atom/keymap'
          @open(atom.keymap.getUserKeymapPath())
        when 'atom://.atom/config'
          @open(atom.config.getUserConfigPath())
        when 'atom://.atom/init-script'
          @open(atom.getUserInitScriptPath())

  # Called by the Serializable mixin during deserialization
  deserializeParams: (params) ->
    params.paneContainer = PaneContainer.deserialize(params.paneContainer)
    params

  # Called by the Serializable mixin during serialization.
  serializeParams: ->
    paneContainer: @paneContainer.serialize()
    fullScreen: atom.isFullScreen()

  # Public: Calls callback for every existing {Editor} and for all new {Editors}
  # that are created.
  #
  # callback - A {Function} with an {Editor} as its only argument
  eachEditor: (callback) ->
    atom.project.eachEditor(callback)

  # Public: Returns an {Array} of all open {Editor}s.
  getEditors: ->
    atom.project.getEditors()

  # Public: Asynchronously opens a given a filepath in Atom.
  #
  # uri - A {String} uri.
  # options  - An options {Object} (default: {}).
  #   :initialLine - A {Number} indicating which line number to open to.
  #   :split - A {String} ('left' or 'right') that opens the filePath in a new
  #            pane or an existing one if it exists.
  #   :changeFocus - A {Boolean} that allows the filePath to be opened without
  #                  changing focus.
  #   :searchAllPanes - A {Boolean} that will open existing editors from any pane
  #                     if the uri is already open (default: false)
  #
  # Returns a promise that resolves to the {Editor} for the file URI.
  open: (uri, options={}) ->
    searchAllPanes = options.searchAllPanes
    split = options.split
    uri = atom.project.relativize(uri) ? ''

    pane = switch split
      when 'left'
        @activePane.findLeftmostSibling()
      when 'right'
        @activePane.findOrCreateRightmostSibling()
      else
        if searchAllPanes
          @paneContainer.paneForUri(uri) ? @activePane
        else
          @activePane

    @openUriInPane(uri, pane, options)

  # Only used in specs
  openSync: (uri, options={}) ->
    {initialLine} = options
    # TODO: Remove deprecated changeFocus option
    activatePane = options.activatePane ? options.changeFocus ? true
    uri = atom.project.relativize(uri) ? ''

    item = @activePane.itemForUri(uri)
    if uri
      item ?= opener(atom.project.resolve(uri), options) for opener in @getOpeners() when !item
    item ?= atom.project.openSync(uri, {initialLine})

    @activePane.activateItem(item)
    @itemOpened(item)
    @activePane.activate() if activatePane
    item

  openUriInPane: (uri, pane, options={}) ->
    changeFocus = options.changeFocus ? true

    item = pane.itemForUri(uri)
    if uri
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

  # Public: Reopens the last-closed item uri if it hasn't already been reopened.
  reopenItemSync: ->
    if uri = @destroyedItemUris.pop()
      @openSync(uri)

  # Public: Register an opener for a uri.
  #
  # An {Editor} will be used if no openers return a value.
  #
  # ## Example
  # ```coffeescript
  #   atom.project.registerOpener (uri) ->
  #     if path.extname(uri) is '.toml'
  #       return new TomlEditor(uri)
  # ```
  #
  # opener - A {Function} to be called when a path is being opened.
  registerOpener: (opener) ->
    atom.project.registerOpener(opener)

  # Public: Remove a registered opener.
  unregisterOpener: (opener) ->
    atom.project.unregisterOpener(opener)

  getOpeners: ->
    atom.project.openers

  # Public: save the active item.
  saveActivePaneItem: ->
    @activePane?.saveActiveItem()

  # Public: save the active item as.
  saveActivePaneItemAs: ->
    @activePane?.saveActiveItemAs()

  # Public: destroy/close the active item.
  destroyActivePaneItem: ->
    @activePane?.destroyActiveItem()

  # Public: destroy/close the active pane.
  destroyActivePane: ->
    @activePane?.destroy()

  # Public: Returns an {Editor} if the active pane item is an {Editor},
  # or null otherwise.
  getActiveEditor: ->
    @activePane?.getActiveEditor()

  increaseFontSize: ->
    atom.config.set("editor.fontSize", atom.config.get("editor.fontSize") + 1)

  decreaseFontSize: ->
    fontSize = atom.config.get("editor.fontSize")
    atom.config.set("editor.fontSize", fontSize - 1) if fontSize > 1

  resetFontSize: ->
    atom.config.restoreDefault("editor.fontSize")

  # Removes the item's uri from the list of potential items to reopen.
  itemOpened: (item) ->
    if uri = item.getUri?()
      remove(@destroyedItemUris, uri)

  # Adds the destroyed item's uri to the list of items to reopen.
  onPaneItemDestroyed: (item) =>
    if uri = item.getUri?()
      @destroyedItemUris.push(uri)

  # Called by Model superclass when destroyed
  destroyed: ->
    @paneContainer.destroy()
