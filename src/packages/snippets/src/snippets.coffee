fs = require 'fs'
PEG = require 'pegjs'
_ = require 'underscore'
SnippetExpansion = require 'snippets/src/snippet-expansion'
Snippet = require './snippet'
require './package-extensions'

module.exports =
  snippetsByExtension: {}
  parser: PEG.buildParser(fs.read(require.resolve 'snippets/snippets.pegjs'), trackLineAndColumn: true)
  userSnippetsDir: fs.join(config.configDirPath, 'snippets')

  activate: (@rootView) ->
    window.snippets = this
    @loadAll()
    @rootView.on 'editor:attached', (e, editor) => @enableSnippetsInEditor(editor)

  loadAll: ->
    for pack in atom.getPackages()
      pack.loadSnippets()

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
      prefix = editSession.getCursor().getCurrentWordPrefix()
      if snippet = syntax.getProperty(editSession.getCursorScopes(), "snippets.#{prefix}")
        editSession.transact ->
          new SnippetExpansion(snippet, editSession)
      else
        e.abortKeyBinding()

    editor.command 'snippets:next-tab-stop', (e) ->
      unless editor.activeEditSession.snippetExpansion?.goToNextTabStop()
        e.abortKeyBinding()

    editor.command 'snippets:previous-tab-stop', (e) ->
      unless editor.activeEditSession.snippetExpansion?.goToPreviousTabStop()
        e.abortKeyBinding()
