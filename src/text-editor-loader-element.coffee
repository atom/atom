class TextEditorLoaderElement extends HTMLElement
  createdCallback: ->
    progressBar = document.createElement('div')
    progressBar.classList.add('progress-bar')
    @progressIndicator = document.createElement('div')
    @progressIndicator.classList.add('progress-indicator')
    progressBar.appendChild(@progressIndicator)
    @appendChild(progressBar)

  attachedCallback: ->
    @initialize(@model) if @model?

  detachedCallback: ->
    @modelSubscription.dispose()

  initialize: (@model) ->
    @updateProgress(@model.getLoadProgress())
    @modelSubscription = @model.onDidChangeLoadProgress(@updateProgress.bind(this))
    this

  updateProgress: (progress) ->
    @progressIndicator.style.width = "#{Math.round(progress * 100)}%"

module.exports = TextEditorLoaderElement = document.registerElement 'atom-text-editor-loader',
  prototype: TextEditorLoaderElement.prototype
