fs = require 'fs'
$ = require 'jquery'
ScrollView = require 'scroll-view'
{$$$} = require 'space-pen'

module.exports =
class MarkdownPreviewView extends ScrollView
  @content: ->
    @div class: 'markdown-preview', tabindex: -1

  initialize: (@buffer) ->
    super
    @fetchRenderedMarkdown()

  getTitle: ->
    "Markdown Preview – #{@buffer.getBaseName()}"

  getUri: ->
    "markdown-preview:#{@buffer.getPath()}"

  setErrorHtml: ->
    @html $$$ ->
      @h2 'Previewing Markdown Failed'
      @h3 'Possible Reasons'
      @ul =>
        @li =>
          @span 'You aren\'t online or are unable to reach '
          @a 'github.com', href: 'https://github.com'
          @span '.'

  setLoading: ->
    @html($$$ -> @div class: 'markdown-spinner', 'Loading Markdown...')

  fetchRenderedMarkdown: (text) ->
    @setLoading()
    $.ajax
      url: 'https://api.github.com/markdown'
      type: 'POST'
      dataType: 'html'
      contentType: 'application/json; charset=UTF-8'
      data: JSON.stringify
        mode: 'markdown'
        text: @buffer.getText()
      success: (html) => @html(html)
      error: => @setErrorHtml()
