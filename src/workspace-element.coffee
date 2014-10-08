ipc = require 'ipc'
path = require 'path'
{Disposable, CompositeDisposable} = require 'event-kit'
Grim = require 'grim'
scrollbarStyle = require 'scrollbar-style'
{callAttachHooks} = require 'space-pen'
WorkspaceView = null

module.exports =
class WorkspaceElement extends HTMLElement
  createdCallback: ->
    @subscriptions = new CompositeDisposable
    @initializeContent()
    @observeScrollbarStyle()
    @observeTextEditorFontConfig()
    @createSpacePenShim()

  attachedCallback: ->
    callAttachHooks(this)
    @focus()

  detachedCallback: ->
    @model.destroy()

  initializeContent: ->
    @classList.add 'workspace'
    @setAttribute 'tabindex', -1


    @verticalAxis = document.createElement('div')
    @verticalAxis.classList.add('vertical')

    @horizontalAxis = document.createElement('div')
    @horizontalAxis.classList.add('horizontal')
    @horizontalAxis.appendChild(@verticalAxis)

    @appendChild(@horizontalAxis)

  observeScrollbarStyle: ->
    @subscriptions.add scrollbarStyle.onValue (style) =>
      switch style
        when 'legacy'
          @classList.remove('scrollbars-visible-when-scrolling')
          @classList.add("scrollbars-visible-always")
        when 'overlay'
          @classList.remove('scrollbars-visible-always')
          @classList.add("scrollbars-visible-when-scrolling")

  observeTextEditorFontConfig: ->
    @subscriptions.add atom.config.observe 'editor.fontSize', @setTextEditorFontSize
    @subscriptions.add atom.config.observe 'editor.fontFamily', @setTextEditorFontFamily
    @subscriptions.add atom.config.observe 'editor.lineHeight', @setTextEditorLineHeight

  createSpacePenShim: ->
    WorkspaceView ?= require './workspace-view'
    @__spacePenView = new WorkspaceView(this)

  getModel: -> @model

  setModel: (@model) ->
    @paneContainer = @model.getView(@model.paneContainer)
    @verticalAxis.appendChild(@paneContainer)

    @addEventListener 'focus', @handleFocus.bind(this)
    handleWindowFocus = @handleWindowFocus.bind(this)
    window.addEventListener 'focus', handleWindowFocus
    @subscriptions.add(new Disposable -> window.removeEventListener 'focus', handleWindowFocus)

    @__spacePenView.setModel(@model)

  setTextEditorFontSize: (fontSize) ->
    atom.themes.updateGlobalEditorStyle('font-size', fontSize + 'px')

  setTextEditorFontFamily: (fontFamily) ->
    atom.themes.updateGlobalEditorStyle('font-family', fontFamily)

  setTextEditorLineHeight: (lineHeight) ->
    atom.themes.updateGlobalEditorStyle('line-height', lineHeight)

  handleFocus: (event) ->
    @model.getActivePane().activate()

  handleWindowFocus: (event) ->
    @handleFocus(event) if document.activeElement is document.body

  focusPaneViewAbove: -> @paneContainer.focusPaneViewAbove()

  focusPaneViewBelow: -> @paneContainer.focusPaneViewBelow()

  focusPaneViewOnLeft: -> @paneContainer.focusPaneViewOnLeft()

  focusPaneViewOnRight: -> @paneContainer.focusPaneViewOnRight()

atom.commands.add 'atom-workspace',
  'window:increase-font-size': -> @getModel().increaseFontSize()
  'window:decrease-font-size': -> @getModel().decreaseFontSize()
  'window:reset-font-size': -> @getModel().resetFontSize()
  'application:about': -> ipc.send('command', 'application:about')
  'application:run-all-specs': -> ipc.send('command', 'application:run-all-specs')
  'application:run-benchmarks': -> ipc.send('command', 'application:run-benchmarks')
  'application:show-settings': -> ipc.send('command', 'application:show-settings')
  'application:quit': -> ipc.send('command', 'application:quit')
  'application:hide': -> ipc.send('command', 'application:hide')
  'application:hide-other-applications': -> ipc.send('command', 'application:hide-other-applications')
  'application:install-update': -> ipc.send('command', 'application:install-update')
  'application:unhide-all-applications': -> ipc.send('command', 'application:unhide-all-applications')
  'application:new-window': -> ipc.send('command', 'application:new-window')
  'application:new-file': -> ipc.send('command', 'application:new-file')
  'application:open': -> ipc.send('command', 'application:open')
  'application:open-file': -> ipc.send('command', 'application:open-file')
  'application:open-folder': -> ipc.send('command', 'application:open-folder')
  'application:open-dev': -> ipc.send('command', 'application:open-dev')
  'application:open-safe': -> ipc.send('command', 'application:open-safe')
  'application:minimize': -> ipc.send('command', 'application:minimize')
  'application:zoom': -> ipc.send('command', 'application:zoom')
  'application:bring-all-windows-to-front': -> ipc.send('command', 'application:bring-all-windows-to-front')
  'application:open-your-config': -> ipc.send('command', 'application:open-your-config')
  'application:open-your-init-script': -> ipc.send('command', 'application:open-your-init-script')
  'application:open-your-keymap': -> ipc.send('command', 'application:open-your-keymap')
  'application:open-your-snippets': -> ipc.send('command', 'application:open-your-snippets')
  'application:open-your-stylesheet': -> ipc.send('command', 'application:open-your-stylesheet')
  'application:open-license': -> @getModel().openLicense()
  'window:run-package-specs': -> ipc.send('run-package-specs', path.join(atom.project.getPath(), 'spec'))
  'window:focus-next-pane': -> @getModel().activateNextPane()
  'window:focus-previous-pane': -> @getModel().activatePreviousPane()
  'window:focus-pane-above': -> @focusPaneViewAbove()
  'window:focus-pane-below': -> @focusPaneViewBelow()
  'window:focus-pane-on-left': -> @focusPaneViewOnLeft()
  'window:focus-pane-on-right': -> @focusPaneViewOnRight()
  'window:save-all': -> @getModel().saveAll()
  'window:toggle-invisibles': -> atom.config.toggle("editor.showInvisibles")
  'window:log-deprecation-warnings': -> Grim.logDeprecationWarnings()
  'window:toggle-auto-indent': -> atom.config.toggle("editor.autoIndent")
  'pane:reopen-closed-item': -> @getModel().reopenItem()
  'core:close': -> @getModel().destroyActivePaneItemOrEmptyPane()
  'core:save': -> @getModel().saveActivePaneItem()
  'core:save-as': -> @getModel().saveActivePaneItemAs()

if process.platform is 'darwin'
  atom.commands.add 'atom-workspace', 'window:install-shell-commands', -> @getModel().installShellCommands()

module.exports = WorkspaceElement = document.registerElement 'atom-workspace', prototype: WorkspaceElement.prototype
