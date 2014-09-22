isHighSurrogate = (string, index) ->
  0xD800 <= string.charCodeAt(index) <= 0xDBFF

isLowSurrogate = (string, index) ->
  0xDC00 <= string.charCodeAt(index) <= 0xDFFF

isVariationSelector = (string, index) ->
  0xFE00 <= string.charCodeAt(index) <= 0xFE0F

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

# Is the character at the given index the start of high/low surrogate pair
# or a variation sequence?
#
# * `string` The {String} to check for a surrogate pair or variation sequence.
# * `index`  The {Number} index to look for a surrogate pair at.
#
# Return a {Boolean}.
isPairedCharacter = (string, index=0) ->
  isSurrogatePair(string, index) or isVariationSequence(string, index)

# Does the given string contain at least surrogate pair or variation sequence?
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
