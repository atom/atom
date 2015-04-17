# space, CJK 4e00-, kana 3041-, hangul 1100-
breakableRegex = /[\s\u4e00-\u9fff\u3400-\u4dbf\u3041-\u309f\u30a1-\u30ff\u31f0-\u31ff\u1100-\u11ff\u3130-\u318f\uac00-\ud7af]/

module.exports =
class TextWrapContext
  canvas: null
  context: null

  fontFamily: ""
  fontSize: 0

  constructor: ({@fontFamily, @fontSize} = {}) ->
    @canvas = document.createElement("canvas")
    @context = @canvas.getContext("2d")
    @updateCanvas()

  setFontFamily: (@fontFamily) ->
    @updateCanvas()

  setFontSize: (@fontSize) ->
    @updateCanvas()
    
  stringifyFont: ->
    @fontSize + "px " + @fontFamily

  updateCanvas: ->
    @context.font = @stringifyFont()

  # Given a boundary width, finds the point where this line would wrap.
  #
  # lineWrapWidth - The {Number} where you want soft wrapping to occur
  # text - The {String} to soft wrap
  # firstNonWhitespaceIndex - The {Number} where the first non-whitespace character appears
  #
  # Returns a {Number} representing the `line` position where the wrap would take place.
  # Returns `null` if a wrap wouldn't occur.
  findWrapColumn: ({lineWrapWidth, text, firstNonWhitespaceIndex}) ->
    return unless lineWrapWidth?
    return unless @context.measureText(text).width > lineWrapWidth

    # Break the text to get proper width, by binary search algorithm.
    left = 0
    right = text.length
    while left < right
      middle = (left + right) / 2
      slice = text.slice(0, middle)
      measure = @context.measureText(slice)
      if measure.width == lineWrapWidth
        return @findWordWrapColumn({ wordWrapColumn: slice.length, text, firstNonWhitespaceIndex })
      if measure.width < lineWrapWidth
        left = Math.ceil(middle)
      else
        right = Math.floor(middle)

    # Last condition
    if @context.measureText(text.slice(0, left)).width > lineWrapWidth
      left--;

    @findWordWrapColumn({ wordWrapColumn: left, text, firstNonWhitespaceIndex })

  # Prevent word-break
  findWordWrapColumn: ({wordWrapColumn, text, firstNonWhitespaceIndex}) ->
    if breakableRegex.test(text[wordWrapColumn])
      # search forward for the start of a word past the boundary
      # NOTE: .slice method is faster than character indexing method
      # http://jsperf.com/text-wrap-test/2
      firstNonspace = text.slice(wordWrapColumn).search(/\S/)
      return wordWrapColumn + firstNonspace unless firstNonspace == -1

      return text.length
    else
      # search backward for the start of the word on the boundary
      for column in [wordWrapColumn..firstNonWhitespaceIndex]
        return column + 1 if breakableRegex.test(text[column])

      return wordWrapColumn
