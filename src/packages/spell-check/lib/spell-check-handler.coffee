module.exports =
  findMisspellings: (text) ->
    wordRegex = /(?:^|[\s\[\]])([a-zA-Z']+)(?=[\s\.\[\]]|$)/g
    row = 0
    misspellings = []
    for line in text.split('\n')
      while matches = wordRegex.exec(line)
        word = matches[1]
        continue unless $native.isMisspelled(word)
        startColumn = matches.index + matches[0].length - word.length
        endColumn = startColumn + word.length
        misspellings.push([[row, startColumn], [row, endColumn]])
      row++
    callTaskMethod('misspellingsFound', misspellings)
