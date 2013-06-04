isHighSurrogate = (string, index) ->
  0xD800 <= string.charCodeAt(index) <= 0xDBFF

isLowSurrogate = (string, index) ->
  0xDC00 <= string.charCodeAt(index) <= 0xDFFF

isSurrogatePair = (string, index) ->
  isHighSurrogate(string, index) and isLowSurrogate(string, index + 1)

getCharacterCount = (string) ->
  count = string.length
  for index in [0...string.length] when isSurrogatePair(string, index)
    count--
  count

hasSurrogatePairs = (string) ->
  string.length isnt getCharacterCount(string)

module.exports = {getCharacterCount, isSurrogatePair, hasSurrogatePairs}
