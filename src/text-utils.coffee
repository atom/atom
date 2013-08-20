### Internal ###

isHighSurrogate = (string, index) ->
  0xD800 <= string.charCodeAt(index) <= 0xDBFF

isLowSurrogate = (string, index) ->
  0xDC00 <= string.charCodeAt(index) <= 0xDFFF

### Public ###

# Is the character at the given index the start of a high/low surrogate pair?
#
# string - The {String} to check for a surrogate pair.
# index - The {Number} index to look for a surrogate pair at.
#
# Return a {Boolean}.
isSurrogatePair = (string, index=0) ->
  isHighSurrogate(string, index) and isLowSurrogate(string, index + 1)

# Get the number of characters in the string accounting for surrogate pairs.
#
# This method counts high/low surrogate pairs as a single character and will
# always returns a value less than or equal to `string.length`.
#
# string - The {String} to count the number of full characters in.
#
# Returns a {Number}.
getCharacterCount = (string) ->
  count = string.length
  count-- for index in [0...string.length] when isSurrogatePair(string, index)
  count

# Does the given string contain at least one surrogate pair?
#
# string - The {String} to check for the presence of surrogate pairs.
#
# Returns a {Boolean}.
hasSurrogatePair = (string) ->
  string.length isnt getCharacterCount(string)

module.exports = {getCharacterCount, isSurrogatePair, hasSurrogatePair}
