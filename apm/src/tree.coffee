_ = require 'underscore-plus'

module.exports = (items, options={}, callback) ->
  if _.isFunction(options)
    callback = options
    options = {}
  callback ?= (item) -> item

  if items.length is 0
    emptyMessage = options.emptyMessage ? '(empty)'
    console.log "\u2514\u2500\u2500 #{emptyMessage}"
  else
    for item, index in items
      if index is items.length - 1
        itemLine = '\u2514\u2500\u2500 '
      else
        itemLine = '\u251C\u2500\u2500 '
      console.log "#{itemLine}#{callback(item)}"
