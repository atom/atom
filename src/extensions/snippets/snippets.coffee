fs = require 'fs'
PEG = require 'pegjs'

module.exports =
  name: 'Snippets'
  snippetsByExtension: {}
  snippetsParser: PEG.buildParser(fs.read(require.resolve 'extensions/snippets/snippets.pegjs'))

  activate: (@rootView) ->
    rootView.on 'editor-open', (e, editor) =>
      editor.preempt 'tab', =>
        return false if @expandSnippet()

  evalSnippets: (extension, text) ->
    @snippetsByExtension[extension] = @snippetsParser.parse(text)

  expandSnippet: ->
    editSession = @rootView.activeEditor().activeEditSession
    return unless snippets = @snippetsByExtension[editSession.buffer.getExtension()]
    prefix = editSession.getLastCursor().getCurrentWordPrefix()
    if body = snippets[prefix]?.body
      editSession.selectToBeginningOfWord()
      editSession.insertText(body)
      true
