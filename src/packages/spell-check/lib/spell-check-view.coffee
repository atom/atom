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
    @subscribe @editor, 'editor:path-changed', => @subscribeToBuffer()
    @subscribe @editor, 'editor:grammar-changed', => @subscribeToBuffer()
    @observeConfig 'editor.fontSize', => @subscribeToBuffer()
    @observeConfig 'spell-check.grammars', => @subscribeToBuffer()

    @subscribeToBuffer()

  subscribeToBuffer: ->
    @destroyViews()
    @task?.abort()
    return unless @spellCheckCurrentGrammar()

    @buffer?.off '.spell-check'
    @buffer = @editor.getBuffer()
    @buffer.on 'contents-modified.spell-check', => @updateMisspellings()
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

  updateMisspellings: ->
    @task?.abort()

    callback = (misspellings) =>
      @destroyViews()
      @addViews(misspellings)
    @task = new SpellCheckTask(@buffer.getText(), callback)
    @task.start()
