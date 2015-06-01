fs = require 'fs'
TextBuffer = require 'text-buffer'
TokenizedLine = require './tokenized-line'

module.exports = ({filePath, tabLength, invisibles, rootScopeId, chunkSize}) ->
  done = @async()

  buffer = new TextBuffer({filePath})
  buffer.load().then =>
    currentChunk = []
    openScopes = [rootScopeId]
    indentLevel = 0
    lastLineEmpty = false

    for row in [0..buffer.getLastRow()] by 1
      text = buffer.lineForRow(row)
      tags = [text.length]
      lineEnding = buffer.lineEndingForRow(row)
      line = new TokenizedLine({openScopes, text, tags, tabLength, indentLevel, invisibles, lineEnding})

      newIndentLevel = Math.ceil(line.indentLevel)
      if lastLineEmpty and newIndentLevel > indentLevel
        for previousLine in currentChunk by -1
          break unless previousLine.text.length is 0
          previousLine.indentLevel = newIndentLevel

      indentLevel = newIndentLevel
      lastLineEmpty = line.text.length is 0

      currentChunk.push(line)
      if currentChunk.length > chunkSize and not lastLineEmpty
        @emit 'chunk', currentChunk
        currentChunk.length = 0

    @emit 'chunk', currentChunk
    done()
