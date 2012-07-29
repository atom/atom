module.exports =
class Parser
  constructor: (@grammar) ->

  getLineTokens: (line, state=@getStartState()) ->

  getStartState: ->
    console.log @grammar
    [new ParserState(@grammar)]

class ParserState
  scopeName: null
  patterns: null

  constructor: ({@scopeName, patterns}) ->

    @patterns = patterns.map (pattern) ->
      console.log pattern.match

      #matchcount = new RegExp("(?:(" + state[i].regex + ")|(.))").exec("a").length - 2;