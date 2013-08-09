$ = require 'jquery'
_ = require 'underscore'
ScrollView = require 'scroll-view'
{$$$} = require 'space-pen'
roaster = require 'roaster'
Editor = require 'editor'

fenceNameToExtension =
  'bash': 'sh'
  'coffee': 'coffee'
  'coffeescript': 'coffee'
  'coffee-script': 'coffee'
  'css': 'css'
  'go': 'go'
  'java': 'java'
  'javascript': 'js'
  'js': 'js'
  'mustache': 'mustache'
  'python': 'py'
  'rb': 'rb'
  'ruby': 'rb'
  'sh': 'sh'
  'toml': 'toml'
  'xml': 'xml'

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
    syntax.on 'grammar-added grammar-updated', _.debounce((=> @renderMarkdown()), 250)
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
    "#{@buffer.getBaseName()} Preview"

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
