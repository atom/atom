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
  tabStopAnchorRanges: null
  constructor: (@editSession, @snippetsByExtension) ->
    @editSession.on 'move-cursor', => @terminateIfCursorIsOutsideTabStops()

  expandSnippet: ->
    return unless snippets = @snippetsByExtension[@editSession.buffer.getExtension()]
    prefix = @editSession.getLastCursor().getCurrentWordPrefix()
    if snippet = snippets[prefix]
      @editSession.selectToBeginningOfWord()
      startPosition = @editSession.getCursorBufferPosition()
      @editSession.insertText(snippet.body)
      @placeTabStopAnchorRanges(startPosition, snippet.tabStops)
      @indentSnippet(startPosition.row, snippet)
      true
    else
      false

  placeTabStopAnchorRanges: (startPosition, tabStopRanges) ->
    return unless tabStopRanges.length
    @tabStopAnchorRanges = tabStopRanges.map (tabStopRange) =>
      { start, end } = tabStopRange
      @editSession.addAnchorRange([startPosition.add(start), startPosition.add(end)])
    @setTabStopIndex(0)

  indentSnippet: (startRow, snippet) ->
    if snippet.lineCount > 1
      initialIndent = @editSession.lineForBufferRow(startRow).match(/^\s*/)[0]
      for row in [startRow + 1...startRow + snippet.lineCount]
        @editSession.buffer.insert([row, 0], initialIndent)

  goToNextTabStop: ->
    return false unless @ensureValidTabStops()
    nextIndex = @tabStopIndex + 1
    if nextIndex < @tabStopAnchorRanges.length
      @setTabStopIndex(nextIndex)
      true
    else
      @terminateActiveSnippet()
      false

  goToPreviousTabStop: ->
    return false unless @ensureValidTabStops()
    @setTabStopIndex(@tabStopIndex - 1) if @tabStopIndex > 0
    true

  ensureValidTabStops: ->
    @tabStopAnchorRanges? and @terminateIfCursorIsOutsideTabStops()

  setTabStopIndex: (@tabStopIndex) ->
    @editSession.setSelectedBufferRange(@tabStopAnchorRanges[@tabStopIndex].getBufferRange())

  terminateIfCursorIsOutsideTabStops: ->
    return unless @tabStopAnchorRanges
    position = @editSession.getCursorBufferPosition()
    for anchorRange in @tabStopAnchorRanges
      return true if anchorRange.containsBufferPosition(position)
    @terminateActiveSnippet()
    false

  terminateActiveSnippet: ->
    anchorRange.destroy() for anchorRange in @tabStopAnchorRanges
    @tabStopAnchorRanges = null
