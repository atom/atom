$ = require 'jquery'
_ = require 'underscore'

module.exports =
class UILayout
  constructor: (creator) ->
    @content = @createDiv("layout")
    @currentRow = null
    @currentElement = @content
    for name,klass of UILayout.UI.Controls
      do (name, klass) =>
        this[name] = (options={}) ->
          @insert(klass, options)
    creator?.apply(this, [])
  createDiv: (className) ->
    $("<div>").addClass(className)
  insert: (klass,options={}) ->
    view =  new klass(options)
    @currentElement.append(view)
    view.parentView = this
  row: (callback) ->
    [oldRow, @currentRow] = [@currentRow, @createDiv("row")]
    @currentElement.append(@currentRow)
    callback?.apply(this, [])
    @currentRow = oldRow
  column: (options={}, callback=null) ->
    if !callback? && typeof options is "function"
      [callback, options] = [options, null]
    [oldElement, @currentElement] = [@currentElement, @createDiv("column")]
    @currentElement.addClass("align-#{options.align}") if options?.align?
    @currentRow?.append(@currentElement)
    callback?.apply(this, [])
    @currentElement = oldElement
  text: (s) ->
    @currentElement.append(s)