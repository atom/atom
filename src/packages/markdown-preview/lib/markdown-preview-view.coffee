fs = require 'fs'
$ = require 'jquery'
ScrollView = require 'scroll-view'
{$$$} = require 'space-pen'

module.exports =
class MarkdownPreviewView extends ScrollView
  @activate: ->
    @instance = new MarkdownPreviewView
    rootView.command 'markdown-preview:show', '.editor', => @show()

  @show: ->
    activePane = rootView.getActivePane()
    editSession = activePane.activeItem
    if nextPane = activePane.getNextPane()
      if preview = nextPane.itemForUri("markdown-preview:#{editSession.getPath()}")
        nextPane.showItem(preview)
      else
        nextPane.showItem(new MarkdownPreviewView(editSession.buffer))
    else
      activePane.splitRight(new MarkdownPreviewView(editSession.buffer))
    activePane.focus()

  @content: ->
    @div class: 'markdown-preview', tabindex: -1, =>
      @div class: 'markdown-body', outlet: 'markdownBody'

  initialize: (@buffer) ->
    super

    rootView.command 'markdown-preview:toggle', => @toggle()

  getTitle: ->
    "Markdown Preview"

  getUri: ->
    "markdown-preview:#{@buffer.getPath()}"

  toggle: ->
    if @hasParent()
      @detach()
    else
      @attach()

  attach: ->
    return unless @isMarkdownEditor()
    rootView.append(this)
    @markdownBody.html(@getLoadingHtml())
    @loadHtml()
    @focus()

  detach: ->
#     return if @detaching
#     @detaching = true
#     super
#     rootView.focus()
#     @detaching = false

  getActiveText: ->
    rootView.getActiveView()?.getText()

  getErrorHtml: (error) ->
    $$$ ->
      @h2 'Previewing Markdown Failed'
      @h3 'Possible Reasons'
      @ul =>
        @li =>
          @span 'You aren\'t online or are unable to reach '
          @a 'github.com', href: 'https://github.com'
          @span '.'

   getLoadingHtml: ->
     $$$ ->
       @div class: 'markdown-spinner', 'Loading Markdown...'

  loadHtml: (text) ->
    payload =
       mode: 'markdown'
       text: @getActiveText()
    request =
      url: 'https://api.github.com/markdown'
      type: 'POST'
      dataType: 'html'
      contentType: 'application/json; charset=UTF-8'
      data: JSON.stringify(payload)
      success: (html) => @setHtml(html)
      error: (jqXhr, error) => @setHtml(@getErrorHtml(error))
    $.ajax(request)

  setHtml: (html) ->
    @markdownBody.html(html) if @hasParent()

  isMarkdownEditor: (path) ->
    editor = rootView.getActiveView()
    return unless editor?
    return true if editor.getGrammar().scopeName is 'source.gfm'
    path and fs.isMarkdownExtension(fs.extension(path))
