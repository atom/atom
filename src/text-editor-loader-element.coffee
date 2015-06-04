class TextEditorLoaderElement extends HTMLElement
  createdCallback: ->
    @progressElement = document.createElement('progress')
    @progressElement.setAttribute('max', 100)
    @progressElement.setAttribute('value', 0)
    @appendChild(@progressElement)

  attachedCallback: ->
    @initialize(@model) if @model?

  detachedCallback: ->
    @modelSubscription.dispose()

  initialize: (@model) ->
    @updateProgress(@model.getLoadProgress())
    @modelSubscription = @model.onDidChangeLoadProgress(@updateProgress.bind(this))
    this

  updateProgress: (progress) ->
    @progressElement.setAttribute('value', Math.round(progress * 100))

module.exports = TextEditorLoaderElement = document.registerElement 'atom-text-editor-loader',
  prototype: TextEditorLoaderElement.prototype
