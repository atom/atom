module.exports =
class TextEditorLoader
  constructor: (@editor) ->
    @loadDisposable = @editor.onDidLoad => @finishLoading()

  finishLoading: ->
    @loadDisposable.dispose()

    pane = atom.workspace.paneForItem(this)
    myIndex = pane.getItems().indexOf(this)
    pane.addItem(@editor, myIndex + 1)
    pane.destroyItem(this)

  getTitle: ->
    @editor.getTitle()

atom.views.addViewProvider TextEditorLoader, (loader) ->
  node = document.createElement("div")
  node.textContent = "Loading #{loader.getTitle()}..."
  node
