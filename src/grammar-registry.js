const _ = require('underscore-plus')
const FirstMate = require('first-mate')
const {Disposable, CompositeDisposable} = require('event-kit')
const TokenizedBuffer = require('./tokenized-buffer')
const Token = require('./token')
const fs = require('fs-plus')
const {Point, Range} = require('text-buffer')

const GRAMMAR_SELECTION_RANGE = Range(Point.ZERO, Point(10, 0)).freeze()
const PathSplitRegex = new RegExp('[/.]')

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
    this.grammarOverridesByPath = {}
    this.grammarScoresByBuffer = new Map()
    this.subscriptions = new CompositeDisposable()

    const grammarAddedOrUpdated = this.grammarAddedOrUpdated.bind(this)
    this.onDidAddGrammar(grammarAddedOrUpdated)
    this.onDidUpdateGrammar(grammarAddedOrUpdated)
  }

  createToken (value, scopes) {
    return new Token({value, scopes})
  }

  maintainGrammar (buffer) {
    this.assignLanguageModeToBuffer(buffer)

    const pathChangeSubscription = buffer.onDidChangePath(() => {
      this.grammarScoresByBuffer.delete(buffer)
      this.assignLanguageModeToBuffer(buffer)
    })

    this.subscriptions.add(pathChangeSubscription)

    return new Disposable(() => {
      this.subscriptions.remove(pathChangeSubscription)
      pathChangeSubscription.dispose()
    })
  }

  assignLanguageModeToBuffer (buffer) {
    let grammar = null
    const overrideScopeName = this.grammarOverridesByPath[buffer.getPath()]
    if (overrideScopeName) {
      grammar = this.grammarForScopeName(overrideScopeName)
      this.grammarScoresByBuffer.set(buffer, null)
    }

    if (!grammar) {
      const result = this.selectGrammarWithScore(
        buffer.getPath(),
        buffer.getTextInRange(GRAMMAR_SELECTION_RANGE)
      )
      grammar = result.grammar
      this.grammarScoresByBuffer.set(buffer, result.score)
    }

    buffer.setLanguageMode(this.languageModeForGrammarAndBuffer(grammar, buffer))
  }

  languageModeForGrammarAndBuffer (grammar, buffer) {
    return new TokenizedBuffer({grammar, buffer, config: this.config})
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
    let bestMatch = null
    let highestScore = -Infinity
    for (let grammar of this.grammars) {
      const score = this.getGrammarScore(grammar, filePath, fileContents)
      if ((score > highestScore) || (bestMatch == null)) {
        bestMatch = grammar
        highestScore = score
      }
    }
    return {grammar: bestMatch, score: highestScore}
  }

  // Extended: Returns a {Number} representing how well the grammar matches the
  // `filePath` and `contents`.
  getGrammarScore (grammar, filePath, contents) {
    if ((contents == null) && fs.isFileSync(filePath)) {
      contents = fs.readFileSync(filePath, 'utf8')
    }

    let score = this.getGrammarPathScore(grammar, filePath)
    if ((score > 0) && !grammar.bundledPackage) {
      score += 0.125
    }
    if (this.grammarMatchesContents(grammar, contents)) {
      score += 0.25
    }
    return score
  }

  getGrammarPathScore (grammar, filePath) {
    if (!filePath) { return -1 }
    if (process.platform === 'win32') { filePath = filePath.replace(/\\/g, '/') }

    const pathComponents = filePath.toLowerCase().split(PathSplitRegex)
    let pathScore = -1

    let customFileTypes
    if (this.config.get('core.customFileTypes')) {
      customFileTypes = this.config.get('core.customFileTypes')[grammar.scopeName]
    }

    let { fileTypes } = grammar
    if (customFileTypes) {
      fileTypes = fileTypes.concat(customFileTypes)
    }

    for (let i = 0; i < fileTypes.length; i++) {
      const fileType = fileTypes[i]
      const fileTypeComponents = fileType.toLowerCase().split(PathSplitRegex)
      const pathSuffix = pathComponents.slice(-fileTypeComponents.length)
      if (_.isEqual(pathSuffix, fileTypeComponents)) {
        pathScore = Math.max(pathScore, fileType.length)
        if (i >= grammar.fileTypes.length) {
          pathScore += 0.5
        }
      }
    }

    return pathScore
  }

  grammarMatchesContents (grammar, contents) {
    if ((contents == null) || (grammar.firstLineRegex == null)) { return false }

    let escaped = false
    let numberOfNewlinesInRegex = 0
    for (let character of grammar.firstLineRegex.source) {
      switch (character) {
        case '\\':
          escaped = !escaped
          break
        case 'n':
          if (escaped) { numberOfNewlinesInRegex++ }
          escaped = false
          break
        default:
          escaped = false
      }
    }
    const lines = contents.split('\n')
    return grammar.firstLineRegex.testSync(lines.slice(0, numberOfNewlinesInRegex + 1).join('\n'))
  }

  // Get the grammar override for the given file path.
  //
  // * `filePath` A {String} file path.
  //
  // Returns a {String} such as `"source.js"`.
  grammarOverrideForPath (filePath) {
    return this.grammarOverridesByPath[filePath]
  }

  // Set the grammar override for the given file path.
  //
  // * `filePath` A non-empty {String} file path.
  // * `scopeName` A {String} such as `"source.js"`.
  //
  // Returns undefined.
  setGrammarOverrideForPath (filePath, scopeName) {
    this.grammarOverridesByPath[filePath] = scopeName
  }

  // Remove the grammar override for the given file path.
  //
  // * `filePath` A {String} file path.
  //
  // Returns undefined.
  clearGrammarOverrideForPath (filePath) {
    delete this.grammarOverridesByPath[filePath]
  }

  grammarAddedOrUpdated (grammar) {
    this.grammarScoresByBuffer.forEach((score, buffer) => {
      const languageMode = buffer.getLanguageMode()
      if (grammar.injectionSelector) {
        if (languageMode.hasTokenForSelector(grammar.injectionSelector)) {
          languageMode.retokenizeLines()
        }
        return
      }

      const grammarOverride = this.grammarOverridesByPath[buffer.getPath()]
      if (grammarOverride) {
        if (grammar.scopeName === grammarOverride) {
          buffer.setLanguageMode(this.languageModeForGrammarAndBuffer(grammar, buffer))
        }
      } else {
        const score = this.getGrammarScore(
          grammar,
          buffer.getPath(),
          buffer.getTextInRange(GRAMMAR_SELECTION_RANGE)
        )

        let currentScore = this.grammarScoresByBuffer.get(buffer)
        if (currentScore == null || score > currentScore) {
          buffer.setLanguageMode(this.languageModeForGrammarAndBuffer(grammar, buffer))
          this.grammarScoresByBuffer.set(buffer, score)
        }
      }
    })
  }
}
