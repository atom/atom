fs = require 'fs'
PEG = require 'pegjs'
_ = require 'underscore'

module.exports =
  name: 'Snippets'
  snippetsByExtension: {}
  snippetsParser: PEG.buildParser(fs.read(require.resolve 'extensions/snippets/snippets.pegjs'), trackLineAndColumn: true)

  activate: (@rootView) ->
    @loadSnippets()
    @rootView.on 'editor-open', (e, editor) => @enableSnippetsInEditor(editor)

  loadSnippets: ->
    snippetsDir = fs.join(atom.configDirPath, 'snippets')
    return unless fs.exists(snippetsDir)
    @loadSnippetsFile(path) for path in fs.list(snippetsDir) when fs.extension(path) == '.snippets'

  loadSnippetsFile: (path) ->
    @evalSnippets(fs.base(path, '.snippets'), fs.read(path))

  evalSnippets: (extension, text) ->
    @snippetsByExtension[extension] = @snippetsParser.parse(text)

  enableSnippetsInEditor: (editor) ->
    editor.on 'snippets:expand', (e) =>
      editSession = editor.activeEditSession
      editSession.snippetsSession ?= new SnippetsSession(editSession, @snippetsByExtension)
      e.abortKeyBinding() unless editSession.snippetsSession.expandSnippet()

    editor.on 'snippets:next-tab-stop', (e) ->
      editSession = editor.activeEditSession
      e.abortKeyBinding() unless editSession.snippetsSession?.goToNextTabStop()


class SnippetsSession
  constructor: (@editSession, @snippetsByExtension) ->

  expandSnippet: ->
    return unless snippets = @snippetsByExtension[@editSession.buffer.getExtension()]
    prefix = @editSession.getLastCursor().getCurrentWordPrefix()
    if @activeSnippet = snippets[prefix]
      @editSession.selectToBeginningOfWord()
      @activeSnippetStartPosition = @editSession.getCursorBufferPosition()
      @editSession.insertText(@activeSnippet.body)
      @setTabStopIndex(0) if @activeSnippet.tabStops.length
      true
    else
      false

  goToNextTabStop: ->
    return false unless @activeSnippet
    @setTabStopIndex(@tabStopIndex + 1)

  setTabStopIndex: (@tabStopIndex) ->
    tabStopPosition = @activeSnippet.tabStops[@tabStopIndex].subtract(@activeSnippetStartPosition)
    @editSession.setCursorBufferPosition(tabStopPosition)
