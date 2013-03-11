AtomPackage = require 'atom-package'
fs = require 'fs'
_ = nodeRequire 'underscore'
SnippetExpansion = require './snippet-expansion'
Snippet = require './snippet'
LoadSnippetsTask = require './load-snippets-task'

module.exports =
  snippetsByExtension: {}
  loaded: false

  activate: ->
    window.snippets = this
    @loadAll()
    rootView.eachEditor (editor) =>
      @enableSnippetsInEditor(editor) if editor.attached

  deactivate: ->
    @loadSnippetsTask?.abort()

  loadAll: ->
    @loadSnippetsTask = new LoadSnippetsTask(this)
    @loadSnippetsTask.start()

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
        { prefix, body, bodyTree } = attributes
        # if `add` isn't called by the loader task (in specs for example), we need to parse the body
        bodyTree ?= @getBodyParser().parse(body)
        snippet = new Snippet({name, prefix, bodyTree})
        snippetsByPrefix[snippet.prefix] = snippet
      syntax.addProperties(selector, snippets: snippetsByPrefix)

  getBodyParser: ->
    require 'snippets/lib/snippet-body-parser'

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
