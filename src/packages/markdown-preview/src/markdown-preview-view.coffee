ScrollView = require 'scroll-view'
fs = require 'fs'
$ = require 'jquery'
{$$$} = require 'space-pen'

module.exports =
class MarkdownPreviewView extends ScrollView
  @activate: (rootView, state) ->
    @instance = new this(rootView)

  @content: (rootView) ->
    @div class: 'markdown-preview', tabindex: -1, =>
      @div class: 'markdown-body', outlet: 'markdownBody'

  initialize: (@rootView) ->
    super

    @command 'core:cancel', => @detach() unless @detaching
    @on 'focusout', => @detach() unless @detaching

  toggle: ->
    if @hasParent()
      @detach()
    else
      @attach()

  attach: ->
    return unless @isMarkdownFile(@getActivePath())
    @rootView.append(this)
    @markdownBody.html(@getLoadingHtml())
    @loadHtml()
    @focus()

  detach: ->
    @detaching = true
    super
    @rootView.focus()
    @detaching = false

  getActivePath: ->
    @rootView.getActiveEditor()?.getPath()

  getActiveText: ->
    @rootView.getActiveEditor()?.getText()

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

  isMarkdownFile: (path) ->
    fs.isMarkdownExtension(fs.extension(path))
