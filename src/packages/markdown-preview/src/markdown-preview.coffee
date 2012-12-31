ScrollView = require 'scroll-view'
fs = require 'fs'
$ = require 'jquery'
{$$$} = require 'space-pen'

module.exports =
class MarkdownPreview extends ScrollView
  @activate: (rootView, state) ->
    requireStylesheet 'markdown-preview.css'
    @instance = new this(rootView)

  @content: (rootView) ->
    @div class: 'markdown-preview', tabindex: -1, =>
      @div class: 'markdown-body', outlet: 'markdownBody'

  initialize: (@rootView) ->
    super
    @rootView.command 'markdown-preview:toggle', => @toggle()
    @command 'core:cancel', => @detach()

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
    super()
    @rootView.focus()

  getActivePath: ->
    @rootView.getActiveEditor()?.getPath()

  getActiveText: ->
    @rootView.getActiveEditor()?.getText()

  getErrorHtml: (error) ->
    '<h1>Previewing Markdown Failed</h1>
     <h2>Possible Reasons</h2>
     <ul>
     <li>You aren\'t online or are unable to reach <a href="https://github.com">github.com</a></li>
     </ul>'

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
