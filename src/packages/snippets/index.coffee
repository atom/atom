AtomPackage = require 'atom-package'
fs = require 'fs'
PEG = require 'pegjs'
_ = require 'underscore'
SnippetExpansion = require './src/snippet-expansion'
Snippet = require './src/snippet'
require './src/package-extensions'

module.exports =
class Snippets extends AtomPackage

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

    @loadDirectory(@userSnippetsDir) if fs.exists(@userSnippetsDir)

  loadDirectory: (snippetsDirPath) ->
    for snippetsPath in fs.list(snippetsDirPath) when fs.base(snippetsPath).indexOf('.') isnt 0
      snippets.loadFile(snippetsPath)

  loadFile: (snippetsPath) ->
    try
      snippets = fs.readObject(snippetsPath)
    catch e
      console.warn "Error reading snippets file '#{snippetsPath}'"
    @add(snippets)

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
