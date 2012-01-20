module.exports =
class Text
  constructor: (@string, @raw=false) ->

  toHtml: ->
    if @raw
      @string
    else
      @string
        .replace(/&/g, '&amp;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')

