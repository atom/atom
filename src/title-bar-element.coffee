
module.exports =
class TitleBarElement extends HTMLElement
  initialize: (@model, {@workspace, @themes, @applicationDelegate}) ->

    @classList.add('title-bar')

    @titleElement = document.createElement('div')
    @titleElement.classList.add('title')
    @titleElement.textContent = document.title
    @appendChild @titleElement

    @workspace.onDidChangeActivePaneItem => @updateTitle()
    @themes.onDidChangeActiveThemes => @setSheetOffset()

    @updateTitle()
    return this

  setSheetOffset: ->
    @applicationDelegate.getCurrentWindow().setSheetOffset(@offsetHeight)

  updateTitle: ->
    @titleElement.textContent = document.title

module.exports = TitleBarElement = document.registerElement 'atom-title-bar', prototype: TitleBarElement.prototype
