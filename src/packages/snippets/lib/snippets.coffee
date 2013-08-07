AtomPackage = require 'atom-package'
fs = require 'fs'
fsUtils = require 'fs-utils'
path = require 'path'
_ = require 'underscore'
SnippetExpansion = require './snippet-expansion'
Snippet = require './snippet'
TextMatePackage = require 'text-mate-package'
CSON = require 'season'
async = require 'async'

module.exports =
  snippetsByExtension: {}
  loaded: false

  activate: ->
    window.snippets = this
    @loadAll()
    rootView.eachEditor (editor) =>
      @enableSnippetsInEditor(editor) if editor.attached

  deactivate: ->

  loadAll: ->
    packages = atom.getLoadedPackages()
    packages.push(path: config.configDirPath)
    async.eachSeries packages, @loadSnippetsFromPackage.bind(this), @doneLoading.bind(this)

  doneLoading: ->
    @loaded = true

  loadSnippetsFromPackage: (pack, done) ->
    if pack instanceof TextMatePackage
      @loadTextMateSnippets(pack.path, done)
    else
      @loadAtomSnippets(pack.path, done)

  loadAtomSnippets: (packagePath, done) ->
    snippetsDirPath = path.join(packagePath, 'snippets')
    return done() unless fsUtils.isDirectorySync(snippetsDirPath)

    loadSnippetFile = (filename, done) =>
      return done() if filename.indexOf('.') is 0
      filepath = path.join(snippetsDirPath, filename)
      CSON.readFile filepath, (err, object) =>
        if err
          console.warn "Error reading snippets file '#{filepath}': #{err.stack}"
        else
          @add(object)
        done()

    fs.readdir snippetsDirPath, (err, paths) ->
      async.eachSeries(paths, loadSnippetFile, done)

  loadTextMateSnippets: (bundlePath, done) ->
    snippetsDirPath = path.join(bundlePath, 'Snippets')
    return done() unless fsUtils.isDirectorySync(snippetsDirPath)

    loadSnippetFile = (filename, done) =>
      return done() if filename.indexOf('.') is 0

      filepath = path.join(snippetsDirPath, filename)

      logError = (err) ->
        console.warn "Error reading snippets file '#{filepath}': #{err.stack ? err}"

      try
        fsUtils.readObject filepath, (err, object) =>
          try
            if err
              logError(err)
            else
              @add(@translateTextmateSnippet(object))
          catch err
            logError(err)
          finally
            done()
      catch err
        logError(err)
        done()

    fs.readdir snippetsDirPath, (err, paths) ->
      if err
        console.warn err
        return done()
      async.eachSeries(paths, loadSnippetFile, done)

  translateTextmateSnippet: ({ scope, name, content, tabTrigger }) ->
    scope = syntax.cssSelectorFromScopeSelector(scope) if scope
    scope ?= '*'
    snippetsByScope = {}
    snippetsByName = {}
    snippetsByScope[scope] = snippetsByName
    snippetsByName[name] = { prefix: tabTrigger, body: content }
    snippetsByScope

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
    require './snippet-body-parser'

  enableSnippetsInEditor: (editor) ->
    editor.command 'snippets:expand', (e) =>
      unless editor.getSelection().isEmpty()
        e.abortKeyBinding()
        return

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
