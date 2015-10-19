ipc = require 'ipc'
path = require 'path'
{Disposable, CompositeDisposable} = require 'event-kit'
Grim = require 'grim'
scrollbarStyle = require 'scrollbar-style'

module.exports =
class WorkspaceElement extends HTMLElement
  globalTextEditorStyleSheet: null

  attachedCallback: ->
    @focus()

  detachedCallback: ->
    @subscriptions.dispose()

  initializeContent: ->
    @classList.add 'workspace'
    @setAttribute 'tabindex', -1

    @verticalAxis = document.createElement('atom-workspace-axis')
    @verticalAxis.classList.add('vertical')

    @horizontalAxis = document.createElement('atom-workspace-axis')
    @horizontalAxis.classList.add('horizontal')
    @horizontalAxis.appendChild(@verticalAxis)

    @appendChild(@horizontalAxis)

  observeScrollbarStyle: ->
    @subscriptions.add scrollbarStyle.observePreferredScrollbarStyle (style) =>
      switch style
        when 'legacy'
          @classList.remove('scrollbars-visible-when-scrolling')
          @classList.add("scrollbars-visible-always")
        when 'overlay'
          @classList.remove('scrollbars-visible-always')
          @classList.add("scrollbars-visible-when-scrolling")

  observeTextEditorFontConfig: ->
    @updateGlobalTextEditorStyleSheet()
    @subscriptions.add @config.onDidChange 'editor.fontSize', @updateGlobalTextEditorStyleSheet.bind(this)
    @subscriptions.add @config.onDidChange 'editor.fontFamily', @updateGlobalTextEditorStyleSheet.bind(this)
    @subscriptions.add @config.onDidChange 'editor.lineHeight', @updateGlobalTextEditorStyleSheet.bind(this)

  updateGlobalTextEditorStyleSheet: ->
    styleSheetSource = """
      atom-text-editor {
        font-size: #{@config.get('editor.fontSize')}px;
        font-family: #{@config.get('editor.fontFamily')};
        line-height: #{@config.get('editor.lineHeight')};
      }
    """
    @styles.addStyleSheet(styleSheetSource, sourcePath: 'global-text-editor-styles')

  initialize: (@model, {@views, @workspace, @project, @config, @styles}) ->
    throw new Error("Must pass a views parameter when initializing WorskpaceElements") unless @views?
    throw new Error("Must pass a workspace parameter when initializing WorskpaceElements") unless @workspace?
    throw new Error("Must pass a project parameter when initializing WorskpaceElements") unless @project?
    throw new Error("Must pass a config parameter when initializing WorskpaceElements") unless @config?
    throw new Error("Must pass a styles parameter when initializing WorskpaceElements") unless @styles?

    @subscriptions = new CompositeDisposable
    @initializeContent()
    @observeScrollbarStyle()
    @observeTextEditorFontConfig()

    @paneContainer = @views.getView(@model.paneContainer)
    @verticalAxis.appendChild(@paneContainer)
    @addEventListener 'focus', @handleFocus.bind(this)

    @panelContainers =
      top: @views.getView(@model.panelContainers.top)
      left: @views.getView(@model.panelContainers.left)
      right: @views.getView(@model.panelContainers.right)
      bottom: @views.getView(@model.panelContainers.bottom)
      modal: @views.getView(@model.panelContainers.modal)

    @horizontalAxis.insertBefore(@panelContainers.left, @verticalAxis)
    @horizontalAxis.appendChild(@panelContainers.right)

    @verticalAxis.insertBefore(@panelContainers.top, @paneContainer)
    @verticalAxis.appendChild(@panelContainers.bottom)

    @appendChild(@panelContainers.modal)

    this

  getModel: -> @model

  handleFocus: (event) ->
    @model.getActivePane().activate()

  focusPaneViewAbove: -> @paneContainer.focusPaneViewAbove()

  focusPaneViewBelow: -> @paneContainer.focusPaneViewBelow()

  focusPaneViewOnLeft: -> @paneContainer.focusPaneViewOnLeft()

  focusPaneViewOnRight: -> @paneContainer.focusPaneViewOnRight()

  runPackageSpecs: ->
    if activePath = @workspace.getActivePaneItem()?.getPath?()
      [projectPath] = @project.relativizePath(activePath)
    else
      [projectPath] = @project.getPaths()
    ipc.send('run-package-specs', path.join(projectPath, 'spec')) if projectPath

module.exports = WorkspaceElement = document.registerElement 'atom-workspace', prototype: WorkspaceElement.prototype
