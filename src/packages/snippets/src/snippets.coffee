fs = require 'fs'
PEG = require 'pegjs'
_ = require 'underscore'
SnippetExpansion = require 'snippets/src/snippet-expansion'
Snippet = require './snippet'

module.exports =
  snippetsByExtension: {}
  parser: PEG.buildParser(fs.read(require.resolve 'snippets/snippets.pegjs'), trackLineAndColumn: true)
  userSnippetsDir: fs.join(config.configDirPath, 'snippets')

  activate: (@rootView) ->
    window.snippets = this
    @loadAll()
    @rootView.on 'editor:attached', (e, editor) => @enableSnippetsInEditor(editor)

  loadAll: ->
    for snippetsPath in fs.list(@userSnippetsDir)
      @load(snippetsPath)

  load: (snippetsPath) ->
    @add(fs.readObject(snippetsPath))

  add: (snippetsBySelector) ->
    for selector, snippetsByName of snippetsBySelector
      snippetsByPrefix = {}
      for name, attributes of snippetsByName
        { prefix, body } = attributes
        bodyTree = @parser.parse(body)
        snippet = new Snippet({name, prefix, bodyTree})
        snippetsByPrefix[snippet.prefix] = snippet
      syntax.addProperties(selector, snippets: snippetsByPrefix)


  enableSnippetsInEditor: (editor) ->
    editor.command 'snippets:expand', (e) =>
      editSession = editor.activeEditSession
      prefix = editSession.getLastCursor().getCurrentWordPrefix()
      if snippet = syntax.getProperty(editSession.getCursorScopes(), "snippets.#{prefix}")
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
