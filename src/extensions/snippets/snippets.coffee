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

    editor.on 'snippets:previous-tab-stop', (e) ->
      editSession = editor.activeEditSession
      e.abortKeyBinding() unless editSession.snippetsSession?.goToPreviousTabStop()

class SnippetsSession
  tabStopAnchors: null
  constructor: (@editSession, @snippetsByExtension) ->

  expandSnippet: ->
    return unless snippets = @snippetsByExtension[@editSession.buffer.getExtension()]
    prefix = @editSession.getLastCursor().getCurrentWordPrefix()
    if snippet = snippets[prefix]
      @editSession.selectToBeginningOfWord()
      startPosition = @editSession.getCursorBufferPosition()
      @editSession.insertText(snippet.body)
      @placeTabStopAnchors(startPosition, snippet.tabStops)
      @indentSnippet(startPosition.row, snippet)
      true
    else
      false

  placeTabStopAnchors: (startPosition, tabStopPositions) ->
    return unless tabStopPositions.length
    @tabStopAnchors = tabStopPositions.map (tabStopPosition) =>
      @editSession.addAnchorAtBufferPosition(startPosition.add(tabStopPosition))
    @setTabStopIndex(0)

  indentSnippet: (startRow, snippet) ->
    if snippet.lineCount > 1
      initialIndent = @editSession.lineForBufferRow(startRow).match(/^\s*/)[0]
      for row in [startRow + 1...startRow + snippet.lineCount]
        @editSession.buffer.insert([row, 0], initialIndent)

  goToNextTabStop: ->
    return false unless @tabStopAnchors
    nextIndex = @tabStopIndex + 1
    if nextIndex < @tabStopAnchors.length
      @setTabStopIndex(nextIndex)
      true
    else
      @terminateActiveSnippet()
      false

  goToPreviousTabStop: ->
    return false unless @tabStopAnchors
    @setTabStopIndex(@tabStopIndex - 1) if @tabStopIndex > 0
    true

  setTabStopIndex: (@tabStopIndex) ->
    @editSession.setCursorBufferPosition(@tabStopAnchors[@tabStopIndex].getBufferPosition())

  terminateActiveSnippet: ->
    anchor.destroy() for anchor in @tabStopAnchors
