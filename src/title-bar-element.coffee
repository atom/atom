
module.exports =
class TitleBarElement extends HTMLElement
  initialize: (@model, {@views, @workspace, @project, @config, @styles}) ->

    @classList.add('title-bar')

    @titleElement = document.createElement('div')
    @titleElement.classList.add('title')
    @titleElement.textContent = document.title
    @appendChild @titleElement

    @workspace.onDidChangeActivePaneItem => @updateTitle()

    @updateTitle()

    return this

  updateTitle: =>
    @titleElement.textContent = document.title

module.exports = TitleBarElement = document.registerElement 'atom-title-bar', prototype: TitleBarElement.prototype
