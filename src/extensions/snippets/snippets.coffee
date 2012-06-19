fs = require 'fs'
PEG = require 'pegjs'

module.exports =
  snippetsByExtension: {}
  snippetsParser: PEG.buildParser(fs.read(require.resolve 'extensions/snippets/snippets.pegjs'))

  evalSnippets: (extension, text) ->
    @snippetsByExtension[extension] = snippetsParser.parse(text)

