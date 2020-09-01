const isHighSurrogate = charCode => charCode >= 0xd800 && charCode <= 0xdbff;

const isLowSurrogate = charCode => charCode >= 0xdc00 && charCode <= 0xdfff;

const isVariationSelector = charCode =>
  charCode >= 0xfe00 && charCode <= 0xfe0f;

const isCombiningCharacter = charCode =>
  (charCode >= 0x0300 && charCode <= 0x036f) ||
  (charCode >= 0x1ab0 && charCode <= 0x1aff) ||
  (charCode >= 0x1dc0 && charCode <= 0x1dff) ||
  (charCode >= 0x20d0 && charCode <= 0x20ff) ||
  (charCode >= 0xfe20 && charCode <= 0xfe2f);

// Are the given character codes a high/low surrogate pair?
//
// * `charCodeA` The first character code {Number}.
// * `charCode2` The second character code {Number}.
//
// Return a {Boolean}.
const isSurrogatePair = (charCodeA, charCodeB) =>
  isHighSurrogate(charCodeA) && isLowSurrogate(charCodeB);

// Are the given character codes a variation sequence?
//
// * `charCodeA` The first character code {Number}.
// * `charCode2` The second character code {Number}.
//
// Return a {Boolean}.
const isVariationSequence = (charCodeA, charCodeB) =>
  !isVariationSelector(charCodeA) && isVariationSelector(charCodeB);

// Are the given character codes a combined character pair?
//
// * `charCodeA` The first character code {Number}.
// * `charCode2` The second character code {Number}.
//
// Return a {Boolean}.
const isCombinedCharacter = (charCodeA, charCodeB) =>
  !isCombiningCharacter(charCodeA) && isCombiningCharacter(charCodeB);

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
  const charCodeA = string.charCodeAt(index);
  const charCodeB = string.charCodeAt(index + 1);
  return (
    isSurrogatePair(charCodeA, charCodeB) ||
    isVariationSequence(charCodeA, charCodeB) ||
    isCombinedCharacter(charCodeA, charCodeB)
  );
};

const IsJapaneseKanaCharacter = charCode =>
  charCode >= 0x3000 && charCode <= 0x30ff;

const isCJKUnifiedIdeograph = charCode =>
  charCode >= 0x4e00 && charCode <= 0x9fff;

const isFullWidthForm = charCode =>
  (charCode >= 0xff01 && charCode <= 0xff5e) ||
  (charCode >= 0xffe0 && charCode <= 0xffe6);

const isDoubleWidthCharacter = character => {
  const charCode = character.charCodeAt(0);

  return (
    IsJapaneseKanaCharacter(charCode) ||
    isCJKUnifiedIdeograph(charCode) ||
    isFullWidthForm(charCode)
  );
};

const isHalfWidthCharacter = character => {
  const charCode = character.charCodeAt(0);

  return (
    (charCode >= 0xff65 && charCode <= 0xffdc) ||
    (charCode >= 0xffe8 && charCode <= 0xffee)
  );
};

const isKoreanCharacter = character => {
  const charCode = character.charCodeAt(0);

  return (
    (charCode >= 0xac00 && charCode <= 0xd7a3) ||
    (charCode >= 0x1100 && charCode <= 0x11ff) ||
    (charCode >= 0x3130 && charCode <= 0x318f) ||
    (charCode >= 0xa960 && charCode <= 0xa97f) ||
    (charCode >= 0xd7b0 && charCode <= 0xd7ff)
  );
};

const isCJKCharacter = character =>
  isDoubleWidthCharacter(character) ||
  isHalfWidthCharacter(character) ||
  isKoreanCharacter(character);

const isWordStart = (previousCharacter, character) =>
  (previousCharacter === ' ' ||
    previousCharacter === '\t' ||
    previousCharacter === '-' ||
    previousCharacter === '/') &&
  (character !== ' ' && character !== '\t');

const isWrapBoundary = (previousCharacter, character) =>
  isWordStart(previousCharacter, character) || isCJKCharacter(character);

// Does the given string contain at least surrogate pair, variation sequence,
// or combined character?
//
// * `string` The {String} to check for the presence of paired characters.
//
// Returns a {Boolean}.
const hasPairedCharacter = string => {
  let index = 0;
  while (index < string.length) {
    if (isPairedCharacter(string, index)) {
      return true;
    }
    index++;
  }
  return false;
};

module.exports = {
  isPairedCharacter,
  hasPairedCharacter,
  isDoubleWidthCharacter,
  isHalfWidthCharacter,
  isKoreanCharacter,
  isWrapBoundary
};
