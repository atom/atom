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
# * `string` The {String} to check for a surrogate pair.
# * `index`  The {Number} index to look for a surrogate pair at.
#
# Return a {Boolean}.
isVariationSequence = (string, index=0) ->
  isVariationSelector(string, index + 1)

# Is the character at the given index the start of high/low surrogate pair
# or a variation sequence?
#
# * `string` The {String} to check for a surrogate pair.
# * `index`  The {Number} index to look for a surrogate pair at.
#
# Return a {Boolean}.

isPairedCharacter = (string, index=0) ->
  isSurrogatePair(string, index) or isVariationSequence(string, index)

# Get the number of characters in the string accounting for surrogate pairs and
# variation sequences.
#
# This method counts high/low surrogate pairs and variation sequences as a
# single character and will always returns a value less than or equal to
# `string.length`.
#
# * `string` The {String} to count the number of full characters in.
#
# Returns a {Number}.
getCharacterCount = (string) ->
  count = string.length
  count-- for index in [0...string.length] when isPairedCharacter(string, index)
  count

# Does the given string contain at least surrogate pair or variation sequence?
#
# * `string` The {String} to check for the presence of paired characters.
#
# Returns a {Boolean}.
hasPairedCharacter = (string) ->
  string.length isnt getCharacterCount(string)

module.exports = {getCharacterCount, isPairedCharacter, hasPairedCharacter}
