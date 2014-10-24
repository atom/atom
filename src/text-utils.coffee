isHighSurrogate = (string, index) ->
  0xD800 <= string.charCodeAt(index) <= 0xDBFF

isLowSurrogate = (string, index) ->
  0xDC00 <= string.charCodeAt(index) <= 0xDFFF

isVariationSelector = (string, index) ->
  0xFE00 <= string.charCodeAt(index) <= 0xFE0F

isCombiningCharacter = (string, index) ->
  0x0300 <= string.charCodeAt(index) <= 0x036F or
  0x1AB0 <= string.charCodeAt(index) <= 0x1AFF or
  0x1DC0 <= string.charCodeAt(index) <= 0x1DFF or
  0x20D0 <= string.charCodeAt(index) <= 0x20FF or
  0xFE20 <= string.charCodeAt(index) <= 0xFE2F

# Is the character at the given index the start of a high/low surrogate pair?
#
# * `string` The {String} to check for a surrogate pair.
# * `index`  The {Number} index to look for a surrogate pair at.
#
# Return a {Boolean}.
isSurrogatePair = (string, index=0) ->
  isHighSurrogate(string, index) and isLowSurrogate(string, index + 1)

# Is the character at the given index the start of a variation sequence?
#
# * `string` The {String} to check for a variation sequence.
# * `index`  The {Number} index to look for a variation sequence at.
#
# Return a {Boolean}.
isVariationSequence = (string, index=0) ->
  not isVariationSelector(string, index) and isVariationSelector(string, index + 1)

# Is the character at the given index the start of a combined character pair?
#
# * `string` The {String} to check for a combined character.
# * `index`  The {Number} index to look for a variation sequence at.
#
# Return a {Boolean}.
isCombinedCharacter = (string, index=0) ->
  not isCombiningCharacter(string, index) and isCombiningCharacter(string, index + 1)

# Is the character at the given index the start of high/low surrogate pair
# a variation sequence, or a combined character?
#
# * `string` The {String} to check for a surrogate pair, variation sequence,
#            or combined character.
# * `index`  The {Number} index to look for a surrogate pair at.
#
# Return a {Boolean}.
isPairedCharacter = (string, index=0) ->
  isSurrogatePair(string, index) or isVariationSequence(string, index) or isCombinedCharacter(string, index)

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
