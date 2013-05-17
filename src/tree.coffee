module.exports = (items, callback) ->
  if items.length is 0
    console.log '\u2514\u2500\u2500 (empty)'
  else
    for item, index in items
      if index is items.length - 1
        itemLine = '\u2514\u2500\u2500 '
      else
        itemLine = '\u251C\u2500\u2500 '
      console.log "#{itemLine}#{callback(item)}"
