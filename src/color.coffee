_ = require 'underscore-plus'
ParsedColor = require 'color'

# A simple Color class returned from `atom.config.get` when the value at the
# key path is of type 'color'.
module.exports =
class Color
  @parse: (value) ->
    return null if _.isArray(value)
    return null if _.isFunction(value)
    return null unless _.isObject(value) or _.isString(value)

    try
      parsedColor = new ParsedColor(value)
    catch error
      return null

    new Color(parsedColor)

  constructor: (color) ->
    @red = color.red()
    @green = color.green()
    @blue = color.blue()
    @alpha = color.alpha()

    @red = 0 if isNaN(@red)
    @green = 0 if isNaN(@green)
    @blue = 0 if isNaN(@blue)
    @alpha = 1 if isNaN(@alpha)

  # Public: Returns a {String} in the form `'#abcdef'`
  toHexString: ->
    hexRed = if @red < 10 then "0#{@red.toString(16)}" else @red.toString(16)
    hexGreen = if @green < 10 then "0#{@green.toString(16)}" else @green.toString(16)
    hexBlue = if @blue < 10 then "0#{@blue.toString(16)}" else @blue.toString(16)
    "##{hexRed}#{hexGreen}#{hexBlue}"

  # Public: Returns a {String} in the form `'rgba(25, 50, 75, .9)'`
  toRGBAString: ->
    "rgba(#{@red}, #{@green}, #{@blue}, #{@alpha})"

  isEqual: (color) ->
    return true if this is color
    color = Color.parse(color) unless color instanceof Color
    return false unless color?
    color.red is @red and color.blue is @blue and color.green is @green and color.alpha is @alpha
