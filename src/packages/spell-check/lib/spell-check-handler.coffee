{isMisspelled} = require 'spellchecker'

wordRegex = /(?:^|[\s\[\]])([a-zA-Z']+)(?=[\s\.\[\]:,]|$)/g

module.exports = (text, queue) ->
  row = 0
  misspellings = []
  for line in text.split('\n')
    while matches = wordRegex.exec(line)
      word = matches[1]
      continue unless isMisspelled(word)

      startColumn = matches.index + matches[0].length - word.length
      endColumn = startColumn + word.length
      misspellings.push([[row, startColumn], [row, endColumn]])
    row++
  misspellings
