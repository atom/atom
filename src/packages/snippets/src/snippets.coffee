fs = require 'fs'
PEG = require 'pegjs'
_ = require 'underscore'
SnippetExpansion = require 'snippets/src/snippet-expansion'

module.exports =
  name: 'Snippets'
  snippetsByExtension: {}
  snippetsParser: PEG.buildParser(fs.read(require.resolve 'snippets/snippets.pegjs'), trackLineAndColumn: true)

  activate: (@rootView) ->
    @loadSnippets()
    @rootView.on 'editor-open', (e, editor) => @enableSnippetsInEditor(editor)

  loadSnippets: ->
    snippetsDir = fs.join(config.configDirPath, 'snippets')
    if fs.exists(snippetsDir)
      @loadSnippetsFile(path) for path in fs.list(snippetsDir) when fs.extension(path) == '.snippets'

  loadSnippetsFile: (path) ->
    @evalSnippets(fs.base(path, '.snippets'), fs.read(path))

  evalSnippets: (extension, text) ->
    @snippetsByExtension[extension] = @snippetsParser.parse(text)

  enableSnippetsInEditor: (editor) ->
    editor.command 'snippets:expand', (e) =>
      editSession = editor.activeEditSession
      prefix = editSession.getLastCursor().getCurrentWordPrefix()
      if snippet = @snippetsByExtension[editSession.getFileExtension()]?[prefix]
        editSession.transact ->
          snippetExpansion = new SnippetExpansion(snippet, editSession)
          editSession.snippetExpansion = snippetExpansion
          editSession.pushOperation
            undo: -> snippetExpansion.destroy()
            redo: (editSession) -> snippetExpansion.restore(editSession)
      else
        e.abortKeyBinding()

    editor.command 'snippets:next-tab-stop', (e) ->
      unless editor.activeEditSession.snippetExpansion?.goToNextTabStop()
        e.abortKeyBinding()

    editor.command 'snippets:previous-tab-stop', (e) ->
      unless editor.activeEditSession.snippetExpansion?.goToPreviousTabStop()
        e.abortKeyBinding()
