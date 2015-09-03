isHighSurrogate = (charCode) ->
  0xD800 <= charCode <= 0xDBFF

isLowSurrogate = (charCode) ->
  0xDC00 <= charCode <= 0xDFFF

isVariationSelector = (charCode) ->
  0xFE00 <= charCode <= 0xFE0F

isCombiningCharacter = (charCode) ->
  0x0300 <= charCode <= 0x036F or
  0x1AB0 <= charCode <= 0x1AFF or
  0x1DC0 <= charCode <= 0x1DFF or
  0x20D0 <= charCode <= 0x20FF or
  0xFE20 <= charCode <= 0xFE2F

# Are the given character codes a high/low surrogate pair?
#
# * `charCodeA` The first character code {Number}.
# * `charCode2` The second character code {Number}.
#
# Return a {Boolean}.
isSurrogatePair = (charCodeA, charCodeB) ->
  isHighSurrogate(charCodeA) and isLowSurrogate(charCodeB)

# Are the given character codes a variation sequence?
#
# * `charCodeA` The first character code {Number}.
# * `charCode2` The second character code {Number}.
#
# Return a {Boolean}.
isVariationSequence = (charCodeA, charCodeB) ->
  return false if charCodeA is 0
  not isVariationSelector(charCodeA) and isVariationSelector(charCodeB)

# Are the given character codes a combined character pair?
#
# * `charCodeA` The first character code {Number}.
# * `charCode2` The second character code {Number}.
#
# Return a {Boolean}.
isCombinedCharacter = (charCodeA, charCodeB) ->
  return false if charCodeA is 0
  not isCombiningCharacter(charCodeA) and isCombiningCharacter(charCodeB)

# Is the character at the given index the start of high/low surrogate pair
# a variation sequence, or a combined character?
#
# * `string` The {String} to check for a surrogate pair, variation sequence,
#            or combined character.
# * `index`  The {Number} index to look for a surrogate pair, variation
#            sequence, or combined character.
#
# Return a {Boolean}.
isPairedCharacter = (string, index=0) ->
  charCodeA = string.charCodeAt(index)
  charCodeB = string.charCodeAt(index + 1)
  isSurrogatePair(charCodeA, charCodeB) or
  isVariationSequence(charCodeA, charCodeB) or
  isCombinedCharacter(charCodeA, charCodeB)

# Does the given string contain at least surrogate pair, variation sequence,
# or combined character?
#
# * `string` The {String} to check for the presence of paired characters.
#
# Returns a {Boolean}.
hasPairedCharacter = (string) ->
  index = 0
  while index < string.length
    return true if isPairedCharacter(string, index)
    index++
  false

module.exports = {isPairedCharacter, hasPairedCharacter}
