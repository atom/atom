fs = require 'fs'
PEG = require 'pegjs'

module.exports =
  class Snippets
    @snippetsByExtension: {}
    @snippetsParser: PEG.buildParser(fs.read(require.resolve 'extensions/snippets/snippets.pegjs'))

    @activate: (@rootView) ->
      @loadSnippets()
      rootView.on 'editor-open', (e, editor) => new Snippets(editor)

    @loadSnippets: ->
      snippetsDir = fs.join(atom.configDirPath, 'snippets')
      return unless fs.exists(snippetsDir)

      @loadSnippetsFile(path) for path in fs.list(snippetsDir) when fs.extension(path) == '.snippets'

    @loadSnippetsFile: (path) ->
      @evalSnippets(fs.base(path, '.snippets'), fs.read(path))

    @evalSnippets: (extension, text) ->
      @snippetsByExtension[extension] = @snippetsParser.parse(text)

    constructor: (@editor) ->
      @editor.preempt 'tab', => return false if @expandSnippet()

    expandSnippet: ->
      editSession = @editor.activeEditSession
      return unless snippets = @constructor.snippetsByExtension[editSession.buffer.getExtension()]
      prefix = editSession.getLastCursor().getCurrentWordPrefix()
      if body = snippets[prefix]?.body
        editSession.selectToBeginningOfWord()
        editSession.insertText(body)
        true
