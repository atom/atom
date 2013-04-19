$ = require 'jquery'
ScrollView = require 'scroll-view'
{$$$} = require 'space-pen'
roaster = require 'roaster'

module.exports =
class MarkdownPreviewView extends ScrollView
  registerDeserializer(this)

  @deserialize: ({path}) ->
    new MarkdownPreviewView(project.bufferForPath(path))

  @content: ->
    @div class: 'markdown-preview', tabindex: -1

  initialize: (@buffer) ->
    super

    @fetchRenderedMarkdown()
    @on 'core:move-up', => @scrollUp()
    @on 'core:move-down', => @scrollDown()

  afterAttach: (onDom) ->
    @subscribe @buffer, 'saved', =>
      @fetchRenderedMarkdown()
      pane = @getPane()
      pane.showItem(this) if pane? and pane isnt rootView.getActivePane()

  getPane: ->
    @parent('.item-views').parent('.pane').view()

  serialize: ->
    deserializer: 'MarkdownPreviewView'
    path: @buffer.getPath()

  getTitle: ->
    "Markdown Preview – #{@buffer.getBaseName()}"

  getUri: ->
    "markdown-preview:#{@buffer.getPath()}"

  getPath: ->
    @buffer.getPath()

  setErrorHtml: (result)->
    try failureMessage = JSON.parse(result.responseText).message

    @html $$$ ->
      @h2 'Previewing Markdown Failed'
      if failureMessage?
        @h3 failureMessage
      else
        @h3 'Possible Reasons'
        @ul =>
          @li =>
            @span 'You aren\'t online or are unable to reach '
            @a 'github.com', href: 'https://github.com'
            @span '.'

  setLoading: ->
    @html($$$ -> @div class: 'markdown-spinner', 'Loading Markdown...')

  fetchRenderedMarkdown: ->
    @setLoading()
    roaster(@buffer.getText(), {}, (err, html) =>
      if err
        @setErrorHtml(err)
      else
        @html(html)
    )
