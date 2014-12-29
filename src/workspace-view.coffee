ipc = require 'ipc'
path = require 'path'
Q = require 'q'
_ = require 'underscore-plus'
Delegator = require 'delegato'
{deprecate, logDeprecationWarnings} = require 'grim'
scrollbarStyle = require 'scrollbar-style'
{$, $$, View} = require './space-pen-extensions'
fs = require 'fs-plus'
Workspace = require './workspace'
PaneView = require './pane-view'
PaneContainerView = require './pane-container-view'
TextEditor = require './text-editor'

# Deprecated: The top-level view for the entire window. An instance of this class is
# available via the `atom.workspaceView` global.
#
# It is backed by a model object, an instance of {Workspace}, which is available
# via the `atom.workspace` global or {::getModel}. You should prefer to interact
# with the model object when possible, but it won't always be possible with the
# current API.
#
# ## Adding Perimeter Panels
#
# Use the following methods if possible to attach panels to the perimeter of the
# workspace rather than manipulating the DOM directly to better insulate you to
# changes in the workspace markup:
#
# * {::prependToTop}
# * {::appendToTop}
# * {::prependToBottom}
# * {::appendToBottom}
# * {::prependToLeft}
# * {::appendToLeft}
# * {::prependToRight}
# * {::appendToRight}
#
# ## Requiring in package specs
#
# If you need a `WorkspaceView` instance to test your package, require it via
# the built-in `atom` module.
#
# ```coffee
# {WorkspaceView} = require 'atom'
# ```
#
# You can assign it to the `atom.workspaceView` global in the spec or just use
# it as a local, depending on what you're trying to accomplish. Building the
# `WorkspaceView` is currently expensive, so you should try build a {Workspace}
# instead if possible.
module.exports =
class WorkspaceView extends View
  Delegator.includeInto(this)

  @delegatesProperty 'fullScreen', 'destroyedItemUris', toProperty: 'model'
  @delegatesMethods 'open', 'openSync',
    'saveActivePaneItem', 'saveActivePaneItemAs', 'saveAll', 'destroyActivePaneItem',
    'destroyActivePane', 'increaseFontSize', 'decreaseFontSize', toProperty: 'model'

  constructor: (@element) ->
    unless @element?
      return atom.views.getView(atom.workspace).__spacePenView
    super
    @deprecateViewEvents()

  setModel: (@model) ->
    @horizontal = @find('atom-workspace-axis.horizontal')
    @vertical = @find('atom-workspace-axis.vertical')
    @panes = @find('atom-pane-container').view()
    @subscribe @model.onDidOpen => @trigger 'uri-opened'

  beforeRemove: ->
    @model?.destroy()

  ###
  Section: Accessing the Workspace Model
  ###

  # Essential: Get the underlying model object.
  #
  # Returns a {Workspace}.
  getModel: -> @model

  ###
  Section: Accessing Views
  ###

  # Essential: Register a function to be called for every current and future
  # editor view in the workspace (only includes {TextEditorView}s that are pane
  # items).
  #
  # * `callback` A {Function} with an {TextEditorView} as its only argument.
  #   * `editorView` {TextEditorView}
  #
  # Returns a subscription object with an `.off` method that you can call to
  # unregister the callback.
  eachEditorView: (callback) ->
    callback(editorView) for editorView in @getEditorViews()
    attachedCallback = (e, editorView) ->
      callback(editorView) unless editorView.mini
    @on('editor:attached', attachedCallback)
    off: => @off('editor:attached', attachedCallback)

  # Essential: Register a function to be called for every current and future
  # pane view in the workspace.
  #
  # * `callback` A {Function} with a {PaneView} as its only argument.
  #   * `paneView` {PaneView}
  #
  # Returns a subscription object with an `.off` method that you can call to
  # unregister the callback.
  eachPaneView: (callback) ->
    @panes.eachPaneView(callback)

  # Essential: Get all existing pane views.
  #
  # Prefer {Workspace::getPanes} if you don't need access to the view objects.
  # Also consider using {::eachPaneView} if you want to register a callback for
  # all current and *future* pane views.
  #
  # Returns an Array of all open {PaneView}s.
  getPaneViews: ->
    @panes.getPaneViews()

  # Essential: Get the active pane view.
  #
  # Prefer {Workspace::getActivePane} if you don't actually need access to the
  # view.
  #
  # Returns a {PaneView}.
  getActivePaneView: ->
    @panes.getActivePaneView()

  # Essential: Get the view associated with the active pane item.
  #
  # Returns a view.
  getActiveView: ->
    @panes.getActiveView()

  ###
  Section: Adding elements to the workspace
  ###

  prependToTop: (element) ->
    deprecate 'Please use Workspace::addTopPanel() instead'
    @vertical.prepend(element)

  appendToTop: (element) ->
    deprecate 'Please use Workspace::addTopPanel() instead'
    @panes.before(element)

  prependToBottom: (element) ->
    deprecate 'Please use Workspace::addBottomPanel() instead'
    @panes.after(element)

  appendToBottom: (element) ->
    deprecate 'Please use Workspace::addBottomPanel() instead'
    @vertical.append(element)

  prependToLeft: (element) ->
    deprecate 'Please use Workspace::addLeftPanel() instead'
    @horizontal.prepend(element)

  appendToLeft: (element) ->
    deprecate 'Please use Workspace::addLeftPanel() instead'
    @vertical.before(element)

  prependToRight: (element) ->
    deprecate 'Please use Workspace::addRightPanel() instead'
    @vertical.after(element)

  appendToRight: (element) ->
    deprecate 'Please use Workspace::addRightPanel() instead'
    @horizontal.append(element)

  ###
  Section: Focusing pane views
  ###

  # Focus the previous pane by id.
  focusPreviousPaneView: -> @model.activatePreviousPane()

  # Focus the next pane by id.
  focusNextPaneView: -> @model.activateNextPane()

  # Focus the pane directly above the active pane.
  focusPaneViewAbove: -> @panes.focusPaneViewAbove()

  # Focus the pane directly below the active pane.
  focusPaneViewBelow: -> @panes.focusPaneViewBelow()

  # Focus the pane directly to the left of the active pane.
  focusPaneViewOnLeft: -> @panes.focusPaneViewOnLeft()

  # Focus the pane directly to the right of the active pane.
  focusPaneViewOnRight: -> @panes.focusPaneViewOnRight()

  ###
  Section: Private
  ###

  # Prompts to save all unsaved items
  confirmClose: ->
    @model.confirmClose()

  # Get all editor views.
  #
  # You should prefer {Workspace::getEditors} unless you absolutely need access
  # to the view objects. Also consider using {::eachEditorView}, which will call
  # a callback for all current and *future* editor views.
  #
  # Returns an {Array} of {TextEditorView}s.
  getEditorViews: ->
    for editorElement in @panes.element.querySelectorAll('atom-pane > .item-views > atom-text-editor')
      $(editorElement).view()


  ###
  Section: Deprecated
  ###

  deprecateViewEvents: ->
    originalWorkspaceViewOn = @on

    @on = (eventName) =>
      switch eventName
        when 'beep'
          deprecate('Use Atom::onDidBeep instead')
        when 'cursor:moved'
          deprecate('Use TextEditor::onDidChangeCursorPosition instead')
        when 'editor:attached'
          deprecate('Use TextEditor::onDidAddTextEditor instead')
        when 'editor:detached'
          deprecate('Use TextEditor::onDidDestroy instead')
        when 'editor:will-be-removed'
          deprecate('Use TextEditor::onDidDestroy instead')
        when 'pane:active-item-changed'
          deprecate('Use Pane::onDidChangeActiveItem instead')
        when 'pane:active-item-modified-status-changed'
          deprecate('Use Pane::onDidChangeActiveItem and call onDidChangeModified on the active item instead')
        when 'pane:active-item-title-changed'
          deprecate('Use Pane::onDidChangeActiveItem and call onDidChangeTitle on the active item instead')
        when 'pane:attached'
          deprecate('Use Workspace::onDidAddPane instead')
        when 'pane:became-active'
          deprecate('Use Pane::onDidActivate instead')
        when 'pane:became-inactive'
          deprecate('Use Pane::onDidChangeActive instead')
        when 'pane:item-added'
          deprecate('Use Pane::onDidAddItem instead')
        when 'pane:item-moved'
          deprecate('Use Pane::onDidMoveItem instead')
        when 'pane:item-removed'
          deprecate('Use Pane::onDidRemoveItem instead')
        when 'pane:removed'
          deprecate('Use Pane::onDidDestroy instead')
        when 'pane-container:active-pane-item-changed'
          deprecate('Use Workspace::onDidChangeActivePaneItem instead')
        when 'selection:changed'
          deprecate('Use TextEditor::onDidChangeSelectionRange instead')
        when 'uri-opened'
          deprecate('Use Workspace::onDidOpen instead')
      originalWorkspaceViewOn.apply(this, arguments)

    TextEditorView = require './text-editor-view'
    originalEditorViewOn = TextEditorView::on
    TextEditorView::on = (eventName) ->
      switch eventName
        when 'cursor:moved'
          deprecate('Use TextEditor::onDidChangeCursorPosition instead')
        when 'editor:attached'
          deprecate('Use TextEditor::onDidAddTextEditor instead')
        when 'editor:detached'
          deprecate('Use TextEditor::onDidDestroy instead')
        when 'editor:will-be-removed'
          deprecate('Use TextEditor::onDidDestroy instead')
        when 'selection:changed'
          deprecate('Use TextEditor::onDidChangeSelectionRange instead')
      originalEditorViewOn.apply(this, arguments)

    originalPaneViewOn = PaneView::on
    PaneView::on = (eventName) ->
      switch eventName
        when 'cursor:moved'
          deprecate('Use TextEditor::onDidChangeCursorPosition instead')
        when 'editor:attached'
          deprecate('Use TextEditor::onDidAddTextEditor instead')
        when 'editor:detached'
          deprecate('Use TextEditor::onDidDestroy instead')
        when 'editor:will-be-removed'
          deprecate('Use TextEditor::onDidDestroy instead')
        when 'pane:active-item-changed'
          deprecate('Use Pane::onDidChangeActiveItem instead')
        when 'pane:active-item-modified-status-changed'
          deprecate('Use Pane::onDidChangeActiveItem and call onDidChangeModified on the active item instead')
        when 'pane:active-item-title-changed'
          deprecate('Use Pane::onDidChangeActiveItem and call onDidChangeTitle on the active item instead')
        when 'pane:attached'
          deprecate('Use Workspace::onDidAddPane instead')
        when 'pane:became-active'
          deprecate('Use Pane::onDidActivate instead')
        when 'pane:became-inactive'
          deprecate('Use Pane::onDidChangeActive instead')
        when 'pane:item-added'
          deprecate('Use Pane::onDidAddItem instead')
        when 'pane:item-moved'
          deprecate('Use Pane::onDidMoveItem instead')
        when 'pane:item-removed'
          deprecate('Use Pane::onDidRemoveItem instead')
        when 'pane:removed'
          deprecate('Use Pane::onDidDestroy instead')
        when 'selection:changed'
          deprecate('Use TextEditor::onDidChangeSelectionRange instead')
      originalPaneViewOn.apply(this, arguments)

  # Deprecated
  eachPane: (callback) ->
    deprecate("Use WorkspaceView::eachPaneView instead")
    @eachPaneView(callback)

  # Deprecated
  getPanes: ->
    deprecate("Use WorkspaceView::getPaneViews instead")
    @getPaneViews()

  # Deprecated
  getActivePane: ->
    deprecate("Use WorkspaceView::getActivePaneView instead")
    @getActivePaneView()

  # Deprecated: Call {Workspace::getActivePaneItem} instead.
  getActivePaneItem: ->
    deprecate("Use Workspace::getActivePaneItem instead")
    @model.getActivePaneItem()
