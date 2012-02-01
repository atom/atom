module.exports =
class Highlighter
  buffer: null
  tokenizer: null
  lineTokens: []

  constructor: (@buffer) ->
    @buildTokenizer()
    @tokenizeLines()

  buildTokenizer: ->
    Mode = require("ace/mode/#{@buffer.modeName()}").Mode
    @tokenizer = (new Mode).getTokenizer()

  tokenizeLines: ->
    @lineTokens = []

    state = "start"
    for line in @buffer.getLines()
      { state, tokens } = @tokenizer.getLineTokens(line, state)
      @lineTokens.push tokens

  tokensForLine: (row) ->
    @lineTokens[row]

