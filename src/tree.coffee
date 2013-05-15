module.exports = (items, callback) ->
  for item, index in items
    if index is items.length - 1
      itemLine = '\u2514\u2500\u2500 '
    else
      itemLine = '\u251C\u2500\u2500 '
    console.log "#{itemLine}#{callback(item)}"
