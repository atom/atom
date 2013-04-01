fs = require 'fs-utils'
$ = require 'jquery'
ScrollView = require 'scroll-view'
{$$$} = require 'space-pen'

module.exports =
class DiffView extends ScrollView
  registerDeserializer(this)

  @deserialize: ({path}) ->
    new DiffView(project.bufferForPath(path))

  @content: ->
    @div class: 'editor diff', tabindex: -1

  initialize: (@buffer, @changes) ->
    super
    @createDiffView()
    @on 'core:move-up', => @scrollUp()
    @on 'core:move-down', => @scrollDown()

  serialize: ->
    deserializer: 'DiffView'
    path: @buffer.getPath()

  getTitle: ->
    "Diff – #{@buffer.getBaseName()}"

  getUri: ->
    "diff:#{@buffer.getPath()}"

  getPath: ->
    @buffer.getPath()

  setErrorHtml: ->
    @html $$$ ->
      @h2 'Diff Failed'

  setLoading: ->
    @html($$$ -> @div class: 'diff-spinner', 'Loading Diff...')

  createDiffView: ->
    @html("<pre>" + @changes + "</pre>")
    # $.ajax
    #   url: 'https://api.github.com/markdown'
    #   type: 'POST'
    #   dataType: 'html'
    #   contentType: 'application/json; charset=UTF-8'
    #   data: JSON.stringify
    #     mode: 'markdown'
    #     text: @buffer.getText()
    #   success: (html) => @html(html)
    #   error: => @setErrorHtml()
