const FirstMate = require('first-mate')
const Token = require('./token')
const fs = require('fs-plus')
const Grim = require('grim')

const PATH_MATCH_MAX_LENGTH = 33554431 // 2^25 - 1
const PATH_MATCH_OFFSET = 134217728 // 2^27 = 1 << 27
const CONTENT_MATCH_MAX_LENGTH = 67108863 // 2^26 - 1

// Extended: Syntax class holding the grammars used for tokenizing.
//
// An instance of this class is always available as the `atom.grammars` global.
//
// The Syntax class also contains properties for things such as the
// language-specific comment regexes. See {::getProperty} for more details.
module.exports =
class GrammarRegistry extends FirstMate.GrammarRegistry {
  constructor ({config} = {}) {
    super({maxTokensPerLine: 100, maxLineLength: 1000})
    this.config = config
  }

  createToken (value, scopes) {
    return new Token({value, scopes})
  }

  // Extended: Select a grammar for the given file path and file contents.
  //
  // This picks the best match by checking the file path and contents against
  // each grammar.
  //
  // * `filePath` A {String} file path.
  // * `fileContents` A {String} of text for the file path.
  //
  // Returns a {Grammar}, never null.
  selectGrammar (filePath, fileContents) {
    return this.selectGrammarWithScore(filePath, fileContents).grammar
  }

  selectGrammarWithScore (filePath, fileContents) {
    const bestMatch = {grammar: null, score: 0}
    for (const grammar of this.grammars) {
      const score = this.getGrammarScore(grammar, filePath, fileContents)
      if (score > bestMatch.score || bestMatch.grammar === null) {
        bestMatch.grammar = grammar
        bestMatch.score = score
      }
    }
    return bestMatch
  }

  // Extended: Returns a {Number} representing how well the grammar matches the
  // `filePath` and `contents`.
  getGrammarScore (grammar, filePath, contents) {
    if (contents == null && fs.isFileSync(filePath)) {
      contents = fs.readFileSync(filePath, 'utf8')
    }

    // The score is an integer from range [0, Number.MAX_SAFE_INTEGER] or a
    // value that can be represented in 53 bits. This integer is partitioned
    // into segments that hold sub-scores for various criteria in the order of
    // importance from the most significant bit to the least significant bit.
    // Such encoding ensures that a higher ranking criterion will always
    // overpower all of the lower ranking criteria combined and makes it easy
    // to determine the best match by searching for the highest score.
    //
    // The layout for the integer is as follows [MSB:LSB]:
    //   bits 52:28   length of the longest file path match plus one, zero
    //                indicates no match
    //   bit  27      whether the matched file type was user-defined
    //   bits 26:1    length of the longest 'first line match' plus one, zero
    //                indicates no match
    //   bit   0      whether the package containing the grammar is not bundled
    //                with the editor (only set if any of higher bits has been
    //                set to avoid such packages overriding any unknown file types)
    //
    // In the unlikely event of any of the criteria exceeding the allocated
    // amount of bits, the value will be clamped to the maximum available value
    // for that bit range.
    //
    // Score of 0 indicates that there is no match.
    //
    // Due to bitwise operations only working with integers up to 32 bits in
    // size, all equivalent operations are performed using addition and
    // multiplication of values.
    let score = this.getGrammarPathScore(grammar, filePath) +
                this.getContentScore(grammar, contents)

    if (score > 0 && !grammar.bundledPackage) {
      // Set the bit in position 0.
      ++score
    }
    return score
  }

  getGrammarPathScore (grammar, filePath) {
    if (!filePath) { return 0 }
    if (process.platform === 'win32') { filePath = filePath.replace(/\\/g, '/') }

    const path = filePath.toLowerCase()
    let pathScore = 0

    let customFileTypes
    const allCustomFileTypes = this.config.get('core.customFileTypes')
    if (allCustomFileTypes) {
      customFileTypes = allCustomFileTypes[grammar.scopeName]
    }

    let { fileTypes } = grammar
    if (customFileTypes) {
      fileTypes = fileTypes.concat(customFileTypes)
    }

    for (let i = 0; i < fileTypes.length; i++) {
      const fileType = fileTypes[i].toLowerCase()
      if (fileType && path.endsWith(fileType)) {
        let score = fileType.length
        const lengthDifference = path.length - fileType.length
        if (lengthDifference) {
          const charBeforeMatch = path.charAt(lengthDifference - 1)
          if (charBeforeMatch === '.' || charBeforeMatch === '_') {
            ++score
          } else if (charBeforeMatch !== '/') {
            continue
          }
        }

        // Clamp value, shift left once.
        score = Math.min(score, PATH_MATCH_MAX_LENGTH) * 2

        if (i >= grammar.fileTypes.length) {
          // User defined file type, set the currently least significant bit.
          ++score
        }

        pathScore = Math.max(pathScore, score)
      }
    }

    // Shift the result left by offset.
    return pathScore * PATH_MATCH_OFFSET
  }

  getContentScore (grammar, contents) {
    if (contents == null || grammar.firstLineRegex == null) { return 0 }

    const match = grammar.firstLineRegex.searchSync(contents)
    if (match) {
      // Add one to score due to successful match, clamp value, shift left once.
      return Math.min(match[0].length + 1, CONTENT_MATCH_MAX_LENGTH) * 2
    }
    return 0
  }

  // Deprecated: Get the grammar override for the given file path.
  //
  // * `filePath` A {String} file path.
  //
  // Returns a {String} such as `"source.js"`.
  grammarOverrideForPath (filePath) {
    Grim.deprecate('Use atom.textEditors.getGrammarOverride(editor) instead')

    const editor = getEditorForPath(filePath)
    if (editor) {
      return atom.textEditors.getGrammarOverride(editor)
    }
  }

  // Deprecated: Set the grammar override for the given file path.
  //
  // * `filePath` A non-empty {String} file path.
  // * `scopeName` A {String} such as `"source.js"`.
  //
  // Returns undefined.
  setGrammarOverrideForPath (filePath, scopeName) {
    Grim.deprecate('Use atom.textEditors.setGrammarOverride(editor, scopeName) instead')

    const editor = getEditorForPath(filePath)
    if (editor) {
      atom.textEditors.setGrammarOverride(editor, scopeName)
    }
  }

  // Deprecated: Remove the grammar override for the given file path.
  //
  // * `filePath` A {String} file path.
  //
  // Returns undefined.
  clearGrammarOverrideForPath (filePath) {
    Grim.deprecate('Use atom.textEditors.clearGrammarOverride(editor) instead')

    const editor = getEditorForPath(filePath)
    if (editor) {
      atom.textEditors.clearGrammarOverride(editor)
    }
  }
}

function getEditorForPath (filePath) {
  if (filePath != null) {
    return atom.workspace.getTextEditors().find(editor => editor.getPath() === filePath)
  }
}
