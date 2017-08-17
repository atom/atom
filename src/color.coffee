_ = require 'underscore-plus'
ParsedColor = null

# Essential: A simple color class returned from {Config::get} when the value
# at the key path is of type 'color'.
module.exports =
class Color
  # Essential: Parse a {String} or {Object} into a {Color}.
  #
  # * `value` A {String} such as `'white'`, `#ff00ff`, or
  #   `'rgba(255, 15, 60, .75)'` or an {Object} with `red`, `green`, `blue`,
  #   and `alpha` properties.
  #
  # Returns a {Color} or `null` if it cannot be parsed.
  @parse: (value) ->
    return null if _.isArray(value) or _.isFunction(value)
    return null unless _.isObject(value) or _.isString(value)

    ParsedColor ?= require 'color'

    try
      parsedColor = new ParsedColor(value)
    catch error
      return null

    new Color(parsedColor.red(), parsedColor.green(), parsedColor.blue(), parsedColor.alpha())

  constructor: (red, green, blue, alpha) ->
    Object.defineProperties this,
      red:
        set: (newRed) -> red = parseColor(newRed)
        get: -> red
        enumerable: true
        configurable: false
      green:
        set: (newGreen) -> green = parseColor(newGreen)
        get: -> green
        enumerable: true
        configurable: false
      blue:
        set: (newBlue) -> blue = parseColor(newBlue)
        get: -> blue
        enumerable: true
        configurable: false
      alpha:
        set: (newAlpha) -> alpha = parseAlpha(newAlpha)
        get: -> alpha
        enumerable: true
        configurable: false

    @red = red
    @green = green
    @blue = blue
    @alpha = alpha

  # Essential: Returns a {String} in the form `'#abcdef'`.
  toHexString: ->
    "##{numberToHexString(@red)}#{numberToHexString(@green)}#{numberToHexString(@blue)}"

  # Essential: Returns a {String} in the form `'rgba(25, 50, 75, .9)'`.
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
  alpha = Math.max(alpha, 0)
  alpha = Math.min(alpha, 1)
  alpha

numberToHexString = (number) ->
  hex = number.toString(16)
  hex = "0#{hex}" if number < 16
  hex
