$ = require 'jquery'
_ = require 'underscore'
ScrollView = require 'scroll-view'
{$$$} = require 'space-pen'
roaster = require 'roaster'
Editor = require 'editor'

fenceNameToExtension =
  "coffeescript": "coffee"
  "coffee": "coffee"
  "toml": "toml"
  "ruby": "rb"
  "rb": "rb"
  "go": "go"
  "mustache": "mustache"
  "java": "java"
  "sh": "sh"
  "bash": "sh"
  "js": "js"
  "javascript": "js"

module.exports =
class MarkdownPreviewView extends ScrollView
  registerDeserializer(this)

  @deserialize: ({path}) ->
    new MarkdownPreviewView(project.bufferForPath(path))

  @content: ->
    @div class: 'markdown-preview', tabindex: -1

  initialize: (@buffer) ->
    super

    @renderMarkdown()
    @on 'core:move-up', => @scrollUp()
    @on 'core:move-down', => @scrollDown()

  afterAttach: (onDom) ->
    @subscribe @buffer, 'saved reloaded', =>
      @renderMarkdown()
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

  setErrorHtml: (result) ->
    failureMessage = result?.message

    @html $$$ ->
      @h2 'Previewing Markdown Failed'
      @h3 failureMessage if failureMessage?

  setLoading: ->
    @html($$$ -> @div class: 'markdown-spinner', 'Loading Markdown...')


  tokenizeCodeBlocks: (html) =>
    html = $(html)
    preList = $(html.filter("pre"))

    for preElement in preList.toArray()
      $(preElement).addClass("editor-colors")
      codeBlock = $(preElement.firstChild)

      # go to next block unless this one has a class
      continue unless className = codeBlock.attr('class')

      fenceName = className.replace(/^lang-/, '')
      # go to next block unless the class name matches `lang`
      continue unless extension = fenceNameToExtension[fenceName]
      text = codeBlock.text()

      grammar = syntax.selectGrammar("foo.#{extension}", text)

      codeBlock.empty()
      for tokens in grammar.tokenizeLines(text)
        codeBlock.append(Editor.buildLineHtml({ tokens, text }))

    html

  renderMarkdown: ->
    @setLoading()
    roaster @buffer.getText(), (err, html) =>
      if err
        @setErrorHtml(err)
      else
        @html(@tokenizeCodeBlocks(html))
