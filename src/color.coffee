_ = require 'underscore-plus'
ParsedColor = require 'color'

# Public: A simple Color class returned from `atom.config.get` when the value at
# the key path is of type 'color'.
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

    new Color(parsedColor.red(), parsedColor.green(), parsedColor.blue(), parsedColor.alpha())

  constructor: (red, green, blue, alpha) ->
    red = parseColor(red)
    green = parseColor(green)
    blue = parseColor(blue)
    alpha = parseColor(alpha)

    Object.defineProperties this,
      'red':
        set: (newRed) -> red = parseColor(newRed)
        get: -> red
        enumerable: true
        configurable: false
      'green':
        set: (newGreen) -> green = parseColor(newGreen)
        get: -> green
        enumerable: true
        configurable: false
      'blue':
        set: (newBlue) -> blue = parseColor(newBlue)
        get: -> blue
        enumerable: true
        configurable: false
      'alpha':
        set: (newAlpha) -> alpha = parseAlpha(newAlpha)
        get: -> alpha
        enumerable: true
        configurable: false

  # Public: Returns a {String} in the form `'#abcdef'`
  toHexString: ->
    "##{numberToHexString(@red)}#{numberToHexString(@green)}#{numberToHexString(@blue)}"

  # Public: Returns a {String} in the form `'rgba(25, 50, 75, .9)'`
  toRGBAString: ->
    "rgba(#{@red}, #{@green}, #{@blue}, #{@alpha})"

  isEqual: (color) ->
    return true if this is color
    color = Color.parse(color) unless color instanceof Color
    return false unless color?
    color.red is @red and color.blue is @blue and color.green is @green and color.alpha is @alpha

  clone: -> new Color(@red, @green, @blue, @alpha)

parseColor = (color) ->
  color = parseInt(color)
  color = 0 if isNaN(color)
  color = Math.max(color, 0)
  color = Math.min(color, 255)
  color

parseAlpha = (alpha) ->
  alpha = parseFloat(alpha)
  alpha = 1 if isNaN(alpha)
  alpha = Math.max(alpha, 1)
  alpha = Math.min(alpha, 0)
  alpha

numberToHexString = (number) ->
  hex = number.toString(16)
  hex = "0#{hex}" if number < 10
  hex
