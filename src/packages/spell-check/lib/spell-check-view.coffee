{View} = require 'space-pen'
_ = require 'underscore'
SpellCheckTask = require './spell-check-task'
MisspellingView = require './misspelling-view'

module.exports =
class SpellCheckView extends View
  @content: ->
    @div class: 'spell-check'

  views: []

  initialize: (@editor) ->
    @task = new Task('spell-check/lib/spell-check-handler')
    @subscribe @editor, 'editor:path-changed', @subscribeToBuffer
    @subscribe @editor, 'editor:grammar-changed', @subscribeToBuffer
    @observeConfig 'editor.fontSize', @subscribeToBuffer
    @observeConfig 'spell-check.grammars', @subscribeToBuffer

    @subscribeToBuffer()

  beforeRemove: ->
    @unsubscribeFromBuffer()

  unsubscribeFromBuffer: ->
    @destroyViews()
    @task?.abort()

    if @buffer?
      @buffer.off 'contents-modified', @updateMisspellings
      @buffer = null

  subscribeToBuffer: =>
    @unsubscribeFromBuffer()

    if @spellCheckCurrentGrammar()
      @buffer = @editor.getBuffer()
      @buffer.on 'contents-modified', @updateMisspellings
      @updateMisspellings()

  spellCheckCurrentGrammar: ->
    grammar = @editor.getGrammar().scopeName
    _.contains config.get('spell-check.grammars'), grammar

  destroyViews: ->
    if @views
      view.destroy() for view in @views
      @views = []

  addViews: (misspellings) ->
    for misspelling in misspellings
      view = new MisspellingView(misspelling, @editor)
      @views.push(view)
      @append(view)

  updateMisspellings: =>
    @task.start buffer.getText(), (misspellings) =>
      @destroyViews()
      @addViews(misspellings)
