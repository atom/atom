fs = require 'fs'
path = require 'path'
PEG = require 'pegjs'
_ = require 'underscore'
SnippetExpansion = require 'snippets/src/snippet-expansion'

module.exports =
  name: 'Snippets'
  snippetsByExtension: {}
  snippetsParser: PEG.buildParser(fs.readFileSync(require.resolve('extensions/snippets/snippets.pegjs'), 'utf8'), trackLineAndColumn: true)

  activate: (@rootView) ->
    @loadSnippets()
    @rootView.on 'editor-open', (e, editor) => @enableSnippetsInEditor(editor)

  loadSnippets: ->
    snippetsDir = path.join(atom.configDirPath, 'snippets')
    if fs.existsSync(snippetsDir)
      for fileName in fs.readdirSync(snippetsDir) when path.extname(fileName) == '.snippets'
        snippetPath = path.join(snippetsDir, fileName)
        @loadSnippetsFile(snippetPath)

  loadSnippetsFile: (pathName) ->
    @evalSnippets(path.basename(pathName, '.snippets'), fs.readFileSync(pathName, 'utf8'))

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
