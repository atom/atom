fs = require 'fs'
PEG = require 'pegjs'
_ = require 'underscore'

module.exports =
  class Snippets
    @snippetsByExtension: {}
    @snippetsParser: PEG.buildParser(fs.read(require.resolve 'extensions/snippets/snippets.pegjs'))

    @activate: (@rootView) ->
      @loadSnippets()

      project = rootView.project

      new Snippets(editSession) for editSession in project.editSessions
      project.on 'new-edit-session', (editSession) => new Snippets(editSession)


    @loadSnippets: ->
      snippetsDir = fs.join(atom.configDirPath, 'snippets')
      return unless fs.exists(snippetsDir)

      @loadSnippetsFile(path) for path in fs.list(snippetsDir) when fs.extension(path) == '.snippets'

    @loadSnippetsFile: (path) ->
      @evalSnippets(fs.base(path, '.snippets'), fs.read(path))

    @evalSnippets: (extension, text) ->
      @snippetsByExtension[extension] = @snippetsParser.parse(text)

    constructor: (@editSession) ->
      _.adviseBefore @editSession, 'insertTab', => @expandSnippet()

    expandSnippet: ->
      return unless snippets = @constructor.snippetsByExtension[@editSession.buffer.getExtension()]
      prefix = @editSession.getLastCursor().getCurrentWordPrefix()
      if body = snippets[prefix]?.body
        @editSession.selectToBeginningOfWord()
        @editSession.insertText(body)
        false
