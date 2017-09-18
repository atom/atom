module.exports =
class TokenIterator
  constructor: (@tokenizedBuffer) ->

  reset: (@line) ->
    @index = null
    @startColumn = 0
    @endColumn = 0
    @scopes = @line.openScopes.map (id) => @tokenizedBuffer.grammar.scopeForId(id)
    @scopeStarts = @scopes.slice()
    @scopeEnds = []
    this

  next: ->
    {tags} = @line

    if @index?
      @startColumn = @endColumn
      @scopeEnds.length = 0
      @scopeStarts.length = 0
      @index++
    else
      @index = 0

    while @index < tags.length
      tag = tags[@index]
      if tag < 0
        scope = @tokenizedBuffer.grammar.scopeForId(tag)
        if tag % 2 is 0
          if @scopeStarts[@scopeStarts.length - 1] is scope
            @scopeStarts.pop()
          else
            @scopeEnds.push(scope)
          @scopes.pop()
        else
          @scopeStarts.push(scope)
          @scopes.push(scope)
        @index++
      else
        @endColumn += tag
        @text = @line.text.substring(@startColumn, @endColumn)
        return true

    false

  getScopes: -> @scopes

  getScopeStarts: -> @scopeStarts

  getScopeEnds: -> @scopeEnds

  getText: -> @text

  getBufferStart: -> @startColumn

  getBufferEnd: -> @endColumn
