fs = require 'fs'
PEG = require 'pegjs'
_ = require 'underscore'

module.exports =
  name: 'Snippets'
  snippetsByExtension: {}
  snippetsParser: PEG.buildParser(fs.read(require.resolve 'extensions/snippets/snippets.pegjs'))

  activate: (@rootView) ->
    @loadSnippets()

    for editor in @rootView.editors()
      @enableSnippetsInEditor(editor)

    @rootView.on 'editor-open', (e, editor) =>
      @enableSnippetsInEditor(editor)

  loadSnippets: ->
    snippetsDir = fs.join(atom.configDirPath, 'snippets')
    return unless fs.exists(snippetsDir)
    @loadSnippetsFile(path) for path in fs.list(snippetsDir) when fs.extension(path) == '.snippets'

  loadSnippetsFile: (path) ->
    @evalSnippets(fs.base(path, '.snippets'), fs.read(path))

  evalSnippets: (extension, text) ->
    @snippetsByExtension[extension] = @snippetsParser.parse(text)

  enableSnippetsInEditor: (editor) ->
    editor.preempt 'tab', =>
      editSession = editor.activeEditSession
      editSession.snippetsSession ?= new SnippetsSession(editSession, @snippetsByExtension)
      editSession.snippetsSession.expandSnippet()

class SnippetsSession
  constructor: (@editSession, @snippetsByExtension) ->

  expandSnippet: ->
    return unless snippets = @snippetsByExtension[@editSession.buffer.getExtension()]
    prefix = @editSession.getLastCursor().getCurrentWordPrefix()
    if body = snippets[prefix]?.body
      @editSession.selectToBeginningOfWord()
      @editSession.insertText(body)
      false
