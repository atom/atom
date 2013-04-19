$ = require 'jquery'
_ = require 'underscore'
ScrollView = require 'scroll-view'
{$$$} = require 'space-pen'
roaster = require 'roaster'
LanguageMode = require 'language-mode'
Buffer = require 'text-buffer'

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
    try failureMessage = JSON.parse(result).message

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
        result = @html(html)
        preList = result.find("pre")
        for pre in preList
          grammar = _.find syntax.grammars, (grammar) ->
            return "ruby" == grammar.scopeName.split(".").pop()

          if grammar
            languageMode = new LanguageMode(this, grammar)
            console.log pre
            code = pre.childNodes[0]
            text = code.textContent.split("\n")

            for line in text
              tokens = languageMode.tokenizeLine(text)
              console.log tokens
          #codeBuffer = new Buffer("", text)
          #x = 1
    )
