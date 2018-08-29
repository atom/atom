const isHighSurrogate = (charCode) =>
  charCode >= 0xD800 && charCode <= 0xDBFF

const isLowSurrogate = (charCode) =>
  charCode >= 0xDC00 && charCode <= 0xDFFF

const isVariationSelector = (charCode) =>
  charCode >= 0xFE00 && charCode <= 0xFE0F

const isCombiningCharacter = charCode =>
  (charCode >= 0x0300 && charCode <= 0x036F) ||
  (charCode >= 0x1AB0 && charCode <= 0x1AFF) ||
  (charCode >= 0x1DC0 && charCode <= 0x1DFF) ||
  (charCode >= 0x20D0 && charCode <= 0x20FF) ||
  (charCode >= 0xFE20 && charCode <= 0xFE2F)

// Are the given character codes a high/low surrogate pair?
//
// * `charCodeA` The first character code {Number}.
// * `charCode2` The second character code {Number}.
//
// Return a {Boolean}.
const isSurrogatePair = (charCodeA, charCodeB) =>
  isHighSurrogate(charCodeA) && isLowSurrogate(charCodeB)

// Are the given character codes a variation sequence?
//
// * `charCodeA` The first character code {Number}.
// * `charCode2` The second character code {Number}.
//
// Return a {Boolean}.
const isVariationSequence = (charCodeA, charCodeB) =>
  !isVariationSelector(charCodeA) && isVariationSelector(charCodeB)

// Are the given character codes a combined character pair?
//
// * `charCodeA` The first character code {Number}.
// * `charCode2` The second character code {Number}.
//
// Return a {Boolean}.
const isCombinedCharacter = (charCodeA, charCodeB) =>
  !isCombiningCharacter(charCodeA) && isCombiningCharacter(charCodeB)

// Is the character at the given index the start of high/low surrogate pair
// a variation sequence, or a combined character?
//
// * `string` The {String} to check for a surrogate pair, variation sequence,
//            or combined character.
// * `index`  The {Number} index to look for a surrogate pair, variation
//            sequence, or combined character.
//
// Return a {Boolean}.
const isPairedCharacter = (string, index = 0) => {
  const charCodeA = string.charCodeAt(index)
  const charCodeB = string.charCodeAt(index + 1)
  return isSurrogatePair(charCodeA, charCodeB) ||
    isVariationSequence(charCodeA, charCodeB) ||
    isCombinedCharacter(charCodeA, charCodeB)
}

const IsJapaneseKanaCharacter = charCode =>
  charCode >= 0x3000 && charCode <= 0x30FF

const isCJKUnifiedIdeograph = charCode =>
  charCode >= 0x4E00 && charCode <= 0x9FFF

const isFullWidthForm = charCode =>
  (charCode >= 0xFF01 && charCode <= 0xFF5E) ||
  (charCode >= 0xFFE0 && charCode <= 0xFFE6)

const isDoubleWidthCharacter = (character) => {
  const charCode = character.charCodeAt(0)

  return IsJapaneseKanaCharacter(charCode) ||
  isCJKUnifiedIdeograph(charCode) ||
  isFullWidthForm(charCode)
}

const isHalfWidthCharacter = (character) => {
  const charCode = character.charCodeAt(0)

  return (charCode >= 0xFF65 && charCode <= 0xFFDC) ||
    (charCode >= 0xFFE8 && charCode <= 0xFFEE)
}

const isKoreanCharacter = (character) => {
  const charCode = character.charCodeAt(0)

  return (charCode >= 0xAC00 && charCode <= 0xD7A3) ||
    (charCode >= 0x1100 && charCode <= 0x11FF) ||
    (charCode >= 0x3130 && charCode <= 0x318F) ||
    (charCode >= 0xA960 && charCode <= 0xA97F) ||
    (charCode >= 0xD7B0 && charCode <= 0xD7FF)
}

const isCJKCharacter = (character) =>
  isDoubleWidthCharacter(character) ||
  isHalfWidthCharacter(character) ||
  isKoreanCharacter(character)

const isWordStart = (previousCharacter, character) =>
  ((previousCharacter === ' ') || (previousCharacter === '\t')) &&
  ((character !== ' ') && (character !== '\t'))

const isWrapBoundary = (previousCharacter, character) =>
  isWordStart(previousCharacter, character) || isCJKCharacter(character)

// Does the given string contain at least surrogate pair, variation sequence,
// or combined character?
//
// * `string` The {String} to check for the presence of paired characters.
//
// Returns a {Boolean}.
const hasPairedCharacter = (string) => {
  let index = 0
  while (index < string.length) {
    if (isPairedCharacter(string, index)) { return true }
    index++
  }
  return false
}

module.exports = {
  isPairedCharacter,
  hasPairedCharacter,
  isDoubleWidthCharacter,
  isHalfWidthCharacter,
  isKoreanCharacter,
  isWrapBoundary
}
