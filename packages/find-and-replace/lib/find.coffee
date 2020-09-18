{CompositeDisposable, Disposable, TextBuffer} = require 'atom'

SelectNext = require './select-next'
{History, HistoryCycler} = require './history'
FindOptions = require './find-options'
BufferSearch = require './buffer-search'
getIconServices = require './get-icon-services'
FindView = require './find-view'
ProjectFindView = require './project-find-view'
ResultsModel = require './project/results-model'
ResultsPaneView = require './project/results-pane'
ReporterProxy = require './reporter-proxy'

metricsReporter = new ReporterProxy()

module.exports =
  activate: ({findOptions, findHistory, replaceHistory, pathsHistory}={}) ->
    # Convert old config setting for backward compatibility.
    if atom.config.get('find-and-replace.openProjectFindResultsInRightPane')
      atom.config.set('find-and-replace.projectSearchResultsPaneSplitDirection', 'right')
    atom.config.unset('find-and-replace.openProjectFindResultsInRightPane')

    atom.workspace.addOpener (filePath) ->
      new ResultsPaneView() if filePath.indexOf(ResultsPaneView.URI) isnt -1

    @subscriptions = new CompositeDisposable
    @currentItemSub = new Disposable
    @findHistory = new History(findHistory)
    @replaceHistory = new History(replaceHistory)
    @pathsHistory = new History(pathsHistory)

    @findOptions = new FindOptions(findOptions)
    @findModel = new BufferSearch(@findOptions)
    @resultsModel = new ResultsModel(@findOptions, metricsReporter)

    @subscriptions.add atom.workspace.getCenter().observeActivePaneItem (paneItem) =>
      @subscriptions.delete @currentItemSub
      @currentItemSub.dispose()

      if atom.workspace.isTextEditor(paneItem)
        @findModel.setEditor(paneItem)
      else if paneItem?.observeEmbeddedTextEditor?
        @currentItemSub = paneItem.observeEmbeddedTextEditor (editor) =>
          if atom.workspace.getCenter().getActivePaneItem() is paneItem
            @findModel.setEditor(editor)
        @subscriptions.add @currentItemSub
      else if paneItem?.getEmbeddedTextEditor?
        @findModel.setEditor(paneItem.getEmbeddedTextEditor())
      else
        @findModel.setEditor(null)

    @subscriptions.add atom.commands.add '.find-and-replace, .project-find', 'window:focus-next-pane', ->
      atom.views.getView(atom.workspace).focus()

    @subscriptions.add atom.commands.add 'atom-workspace', 'project-find:show', =>
      @createViews()
      showPanel @projectFindPanel, @findPanel, => @projectFindView.focusFindElement()

    @subscriptions.add atom.commands.add 'atom-workspace', 'project-find:toggle', =>
      @createViews()
      togglePanel @projectFindPanel, @findPanel, => @projectFindView.focusFindElement()

    @subscriptions.add atom.commands.add 'atom-workspace', 'project-find:show-in-current-directory', ({target}) =>
      @createViews()
      @findPanel.hide()
      @projectFindPanel.show()
      @projectFindView.focusFindElement()
      @projectFindView.findInCurrentlySelectedDirectory(target)

    @subscriptions.add atom.commands.add 'atom-workspace', 'find-and-replace:use-selection-as-find-pattern', =>
      return if @projectFindPanel?.isVisible() or @findPanel?.isVisible()
      @createViews()

    @subscriptions.add atom.commands.add 'atom-workspace', 'find-and-replace:use-selection-as-replace-pattern', =>
      return if @projectFindPanel?.isVisible() or @findPanel?.isVisible()
      @createViews()

    @subscriptions.add atom.commands.add 'atom-workspace', 'find-and-replace:toggle', =>
      @createViews()
      togglePanel @findPanel, @projectFindPanel, => @findView.focusFindEditor()

    @subscriptions.add atom.commands.add 'atom-workspace', 'find-and-replace:show', =>
      @createViews()
      showPanel @findPanel, @projectFindPanel, => @findView.focusFindEditor()

    @subscriptions.add atom.commands.add 'atom-workspace', 'find-and-replace:show-replace', =>
      @createViews()
      showPanel @findPanel, @projectFindPanel, => @findView.focusReplaceEditor()

    @subscriptions.add atom.commands.add 'atom-workspace', 'find-and-replace:clear-history', =>
      @findHistory.clear()
      @replaceHistory.clear()

    # Handling cancel in the workspace + code editors
    handleEditorCancel = ({target}) =>
      isMiniEditor = target.tagName is 'ATOM-TEXT-EDITOR' and target.hasAttribute('mini')
      unless isMiniEditor
        @findPanel?.hide()
        @projectFindPanel?.hide()

    @subscriptions.add atom.commands.add 'atom-workspace',
      'core:cancel': handleEditorCancel
      'core:close': handleEditorCancel

    selectNextObjectForEditorElement = (editorElement) =>
      @selectNextObjects ?= new WeakMap()
      editor = editorElement.getModel()
      selectNext = @selectNextObjects.get(editor)
      unless selectNext?
        selectNext = new SelectNext(editor)
        @selectNextObjects.set(editor, selectNext)
      selectNext

    showPanel = (panelToShow, panelToHide, postShowAction) ->
      panelToHide.hide()
      panelToShow.show()
      postShowAction?()

    togglePanel = (panelToToggle, panelToHide, postToggleAction) ->
      panelToHide.hide()

      if panelToToggle.isVisible()
        panelToToggle.hide()
      else
        panelToToggle.show()
        postToggleAction?()

    @subscriptions.add atom.commands.add '.editor:not(.mini)',
      'find-and-replace:select-next': (event) ->
        selectNextObjectForEditorElement(this).findAndSelectNext()
      'find-and-replace:select-all': (event) ->
        selectNextObjectForEditorElement(this).findAndSelectAll()
      'find-and-replace:select-undo': (event) ->
        selectNextObjectForEditorElement(this).undoLastSelection()
      'find-and-replace:select-skip': (event) ->
        selectNextObjectForEditorElement(this).skipCurrentSelection()

  consumeMetricsReporter: (service) ->
    metricsReporter.setReporter(service)
    new Disposable ->
      metricsReporter.unsetReporter()

  consumeElementIcons: (service) ->
    getIconServices().setElementIcons service
    new Disposable ->
      getIconServices().resetElementIcons()

  consumeFileIcons: (service) ->
    getIconServices().setFileIcons service
    new Disposable ->
      getIconServices().resetFileIcons()

  toggleAutocompletions: (value) ->
    if not @findView?
      return
    if value
      @autocompleteSubscriptions = new CompositeDisposable
      disposable = @autocompleteWatchEditor?(@findView.findEditor, ['default'])
      if disposable?
        @autocompleteSubscriptions.add(disposable)
    else
      @autocompleteSubscriptions?.dispose()

  consumeAutocompleteWatchEditor: (watchEditor) ->
    @autocompleteWatchEditor = watchEditor
    atom.config.observe(
      'find-and-replace.autocompleteSearches',
      (value) => @toggleAutocompletions(value))
    new Disposable =>
      @autocompleteSubscriptions?.dispose()
      @autocompleteWatchEditor = null

  provideService: ->
    resultsMarkerLayerForTextEditor: @findModel.resultsMarkerLayerForTextEditor.bind(@findModel)

  createViews: ->
    return if @findView?

    findBuffer = new TextBuffer
    replaceBuffer = new TextBuffer
    pathsBuffer = new TextBuffer

    findHistoryCycler = new HistoryCycler(findBuffer, @findHistory)
    replaceHistoryCycler = new HistoryCycler(replaceBuffer, @replaceHistory)
    pathsHistoryCycler = new HistoryCycler(pathsBuffer, @pathsHistory)

    options = {findBuffer, replaceBuffer, pathsBuffer, findHistoryCycler, replaceHistoryCycler, pathsHistoryCycler}

    @findView = new FindView(@findModel, options)

    @projectFindView = new ProjectFindView(@resultsModel, options)

    @findPanel = atom.workspace.addBottomPanel(item: @findView, visible: false, className: 'tool-panel panel-bottom')
    @projectFindPanel = atom.workspace.addBottomPanel(item: @projectFindView, visible: false, className: 'tool-panel panel-bottom')

    @findView.setPanel(@findPanel)
    @projectFindView.setPanel(@projectFindPanel)

    # HACK: Soooo, we need to get the model to the pane view whenever it is
    # created. Creation could come from the opener below, or, more problematic,
    # from a deserialize call when splitting panes. For now, all pane views will
    # use this same model. This needs to be improved! I dont know the best way
    # to deal with this:
    # 1. How should serialization work in the case of a shared model.
    # 2. Or maybe we create the model each time a new pane is created? Then
    #    ProjectFindView needs to know about each model so it can invoke a search.
    #    And on each new model, it will run the search again.
    #
    # See https://github.com/atom/find-and-replace/issues/63
    #ResultsPaneView.model = @resultsModel
    # This makes projectFindView accesible in ResultsPaneView so that resultsModel
    # can be properly set for ResultsPaneView instances and ProjectFindView instance
    # as different pane views don't necessarily use same models anymore
    # but most recent pane view and projectFindView do
    ResultsPaneView.projectFindView = @projectFindView

    @toggleAutocompletions atom.config.get('find-and-replace.autocompleteSearches')

  deactivate: ->
    @findPanel?.destroy()
    @findPanel = null
    @findView?.destroy()
    @findView = null
    @findModel?.destroy()
    @findModel = null

    @projectFindPanel?.destroy()
    @projectFindPanel = null
    @projectFindView?.destroy()
    @projectFindView = null

    ResultsPaneView.model = null

    @autocompleteSubscriptions?.dispose()
    @autocompleteManagerService = null
    @subscriptions?.dispose()
    @subscriptions = null

  serialize: ->
    findOptions: @findOptions.serialize()
    findHistory: @findHistory.serialize()
    replaceHistory: @replaceHistory.serialize()
    pathsHistory: @pathsHistory.serialize()
