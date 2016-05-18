
module.exports =
class TitleBarElement extends HTMLElement
  initialize: (@model, {@views, @workspace, @project, @config, @styles}) ->

    @classList.add('title-bar')

    @titleElement = document.createElement('div')
    @titleElement.classList.add('title')
    @titleElement.textContent = document.title
    @appendChild @titleElement

    @activeItemSubscription = atom.workspace.onDidChangeActivePaneItem (activeItem) =>
      @subscribeToActiveTextEditor()

    return this

  subscribeToActiveTextEditor: ->
    @cursorSubscription?.dispose()
    @cursorSubscription = @getActiveTextEditor()?.onDidChangeTitle =>
      @updateTitle()
    @updateTitle()

  updateTitle: ->
    @titleElement.textContent = document.title

  getActiveTextEditor: ->
    atom.workspace.getActiveTextEditor()

module.exports = TitleBarElement = document.registerElement 'atom-title-bar', prototype: TitleBarElement.prototype
