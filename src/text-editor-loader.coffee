module.exports =
class TextEditorLoader
  constructor: (@editor) ->
    @loadDisposable = @editor.onDidChangeLoadProgress (progress) =>
      @finishLoading() if progress is 1

  finishLoading: ->
    @loadDisposable.dispose()

    pane = atom.workspace.paneForItem(this)
    myIndex = pane.getItems().indexOf(this)
    pane.addItem(@editor, myIndex + 1)
    pane.destroyItem(this)

  getTitle: ->
    @editor.getTitle()

  getLoadProgress: ->
    @editor.getLoadProgress()

  onDidChangeLoadProgress: (callback) ->
    @editor.onDidChangeLoadProgress(callback)
