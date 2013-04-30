$ = require 'jquery'
_ = require 'underscore'
ScrollView = require 'scroll-view'
{$$$} = require 'space-pen'
roaster = require 'roaster'
Editor = require 'editor'

fenceNameToExtension =
  "coffeescript": "coffee"
  "toml": "toml"
  "ruby": "rb"
  "go": "go"
  "mustache": "mustache"
  "java": "java"

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


  tokenizeCodeBlocks: (html) =>
    html = $(html)
    preList = $(html.filter("pre"))
    editorBackgroundColor = $('.editor').css("background-color")
    rawEditorTextColor = $('.editor .gfm .raw').css("color")

    for codeBlock in preList.toArray()
      $(codeBlock).css("background-color", editorBackgroundColor)
      codeBlock = $(codeBlock.firstChild)
      # set the default raw color of unhiglighted pre tags
      codeBlock.css("color", rawEditorTextColor)

      # go to next block unless this one has a class
      continue unless className = codeBlock.attr('class')

      fenceName = className.replace(/^lang-/, '')
      # go to next block unless the class name is matches `lang`
      continue unless extension = fenceNameToExtension[fenceName]
      text = codeBlock.text()
      syntax.selectGrammar("foo.#{extension}", text)

      # go to next block if this grammar is not mapped
      continue unless grammar = syntax.selectGrammar("foo.#{extension}", text)
      continue if grammar is syntax.nullGrammar

      text = codeBlock.text()
      tokens = grammar.tokenizeLines(text)
      grouping = ""
      for token in tokens
        blockElem = $(Editor.buildHtmlLine(token, text))
        grouping += blockElem.addClass("editor")[0].outerHTML

      codeBlock.replaceWith(grouping)
      # undo default coloring
      codeBlock.css("color", "")

    html

  renderMarkdown: ->
    @setLoading()
    roaster(@buffer.getText(), {}, (err, html) =>
      if err
        @setErrorHtml(err)
      else
        @html(@tokenizeCodeBlocks(html))
    )
