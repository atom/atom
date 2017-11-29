const _ = require('underscore-plus')
const Grim = require('grim')
const FirstMate = require('first-mate')
const {Disposable, CompositeDisposable} = require('event-kit')
const TextMateLanguageMode = require('./text-mate-language-mode')
const Token = require('./token')
const fs = require('fs-plus')
const {Point, Range} = require('text-buffer')

const GRAMMAR_SELECTION_RANGE = Range(Point.ZERO, Point(10, 0)).freeze()
const PATH_SPLIT_REGEX = new RegExp('[/.]')

// Extended: This class holds the grammars used for tokenizing.
//
// An instance of this class is always available as the `atom.grammars` global.
module.exports =
class GrammarRegistry extends FirstMate.GrammarRegistry {
  constructor ({config} = {}) {
    super({maxTokensPerLine: 100, maxLineLength: 1000})
    this.config = config
    this.subscriptions = new CompositeDisposable()
  }

  clear () {
    super.clear()
    if (this.subscriptions) this.subscriptions.dispose()
    this.subscriptions = new CompositeDisposable()
    this.languageOverridesByBufferId = new Map()
    this.grammarScoresByBuffer = new Map()

    const grammarAddedOrUpdated = this.grammarAddedOrUpdated.bind(this)
    this.onDidAddGrammar(grammarAddedOrUpdated)
    this.onDidUpdateGrammar(grammarAddedOrUpdated)
  }

  serialize () {
    const languageOverridesByBufferId = {}
    this.languageOverridesByBufferId.forEach((languageId, bufferId) => {
      languageOverridesByBufferId[bufferId] = languageId
    })
    return {languageOverridesByBufferId}
  }

  deserialize (params) {
    for (const bufferId in params.languageOverridesByBufferId || {}) {
      this.languageOverridesByBufferId.set(
        bufferId,
        params.languageOverridesByBufferId[bufferId]
      )
    }
  }

  createToken (value, scopes) {
    return new Token({value, scopes})
  }

  // Extended: set a {TextBuffer}'s language mode based on its path and content,
  // and continue to update its language mode as grammars are added or updated, or
  // the buffer's file path changes.
  //
  // * `buffer` The {TextBuffer} whose language mode will be maintained.
  //
  // Returns a {Disposable} that can be used to stop updating the buffer's
  // language mode.
  maintainLanguageMode (buffer) {
    this.grammarScoresByBuffer.set(buffer, null)

    const languageOverride = this.languageOverridesByBufferId.get(buffer.id)
    if (languageOverride) {
      this.assignLanguageMode(buffer, languageOverride)
    } else {
      this.autoAssignLanguageMode(buffer)
    }

    const pathChangeSubscription = buffer.onDidChangePath(() => {
      this.grammarScoresByBuffer.delete(buffer)
      if (!this.languageOverridesByBufferId.has(buffer.id)) {
        this.autoAssignLanguageMode(buffer)
      }
    })

    const destroySubscription = buffer.onDidDestroy(() => {
      this.grammarScoresByBuffer.delete(buffer)
      this.languageOverridesByBufferId.delete(buffer.id)
      this.subscriptions.remove(destroySubscription)
      this.subscriptions.remove(pathChangeSubscription)
    })

    this.subscriptions.add(pathChangeSubscription, destroySubscription)

    return new Disposable(() => {
      destroySubscription.dispose()
      pathChangeSubscription.dispose()
      this.subscriptions.remove(pathChangeSubscription)
      this.subscriptions.remove(destroySubscription)
      this.grammarScoresByBuffer.delete(buffer)
      this.languageOverridesByBufferId.delete(buffer.id)
    })
  }

  // Extended: Force a {TextBuffer} to use a different grammar than the
  // one that would otherwise be selected for it.
  //
  // * `buffer` The {TextBuffer} whose gramamr will be set.
  // * `languageId` The {String} id of the desired language.
  //
  // Returns a {Boolean} that indicates whether the language was successfully
  // found.
  assignLanguageMode (buffer, languageId) {
    if (buffer.getBuffer) buffer = buffer.getBuffer()

    let grammar = null
    if (languageId != null) {
      grammar = this.grammarForScopeName(languageId)
      if (!grammar) return false
      this.languageOverridesByBufferId.set(buffer.id, languageId)
    } else {
      this.languageOverridesByBufferId.set(buffer.id, null)
      grammar = this.nullGrammar
    }

    this.grammarScoresByBuffer.set(buffer, null)
    if (grammar.scopeName !== buffer.getLanguageMode().getLanguageId()) {
      buffer.setLanguageMode(this.languageModeForGrammarAndBuffer(grammar, buffer))
    }

    return true
  }

  // Extended: Remove any language mode override that has been set for the
  // given {TextBuffer}. This will assign to the buffer the best language
  // mode available.
  //
  // * `buffer` The {TextBuffer}.
  autoAssignLanguageMode (buffer) {
    const result = this.selectGrammarWithScore(
      buffer.getPath(),
      buffer.getTextInRange(GRAMMAR_SELECTION_RANGE)
    )
    this.languageOverridesByBufferId.delete(buffer.id)
    this.grammarScoresByBuffer.set(buffer, result.score)
    if (result.grammar.scopeName !== buffer.getLanguageMode().getLanguageId()) {
      buffer.setLanguageMode(this.languageModeForGrammarAndBuffer(result.grammar, buffer))
    }
  }

  languageModeForGrammarAndBuffer (grammar, buffer) {
    return new TextMateLanguageMode({grammar, buffer, config: this.config})
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

    const pathComponents = filePath.toLowerCase().split(PATH_SPLIT_REGEX)
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
      const fileTypeComponents = fileType.toLowerCase().split(PATH_SPLIT_REGEX)
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

  // Deprecated: Get the grammar override for the given file path.
  //
  // * `filePath` A {String} file path.
  //
  // Returns a {String} such as `"source.js"`.
  grammarOverrideForPath (filePath) {
    Grim.deprecate('Use buffer.getLanguageMode().getLanguageId() instead')
    const buffer = atom.project.findBufferForPath(filePath)
    if (buffer) return this.languageOverridesByBufferId.get(buffer.id)
  }

  // Deprecated: Set the grammar override for the given file path.
  //
  // * `filePath` A non-empty {String} file path.
  // * `languageId` A {String} such as `"source.js"`.
  //
  // Returns undefined.
  setGrammarOverrideForPath (filePath, languageId) {
    Grim.deprecate('Use atom.grammars.assignLanguageMode(buffer, languageId) instead')
    const buffer = atom.project.findBufferForPath(filePath)
    if (buffer) {
      const grammar = this.grammarForScopeName(languageId)
      if (grammar) this.languageOverridesByBufferId.set(buffer.id, grammar.name)
    }
  }

  // Remove the grammar override for the given file path.
  //
  // * `filePath` A {String} file path.
  //
  // Returns undefined.
  clearGrammarOverrideForPath (filePath) {
    Grim.deprecate('Use atom.grammars.autoAssignLanguageMode(buffer) instead')
    const buffer = atom.project.findBufferForPath(filePath)
    if (buffer) this.languageOverridesByBufferId.delete(buffer.id)
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

      const languageOverride = this.languageOverridesByBufferId.get(buffer.id)

      if ((grammar.scopeName === buffer.getLanguageMode().getLanguageId() ||
           grammar.scopeName === languageOverride)) {
        buffer.setLanguageMode(this.languageModeForGrammarAndBuffer(grammar, buffer))
      } else if (!languageOverride) {
        const score = this.getGrammarScore(
          grammar,
          buffer.getPath(),
          buffer.getTextInRange(GRAMMAR_SELECTION_RANGE)
        )

        const currentScore = this.grammarScoresByBuffer.get(buffer)
        if (currentScore == null || score > currentScore) {
          buffer.setLanguageMode(this.languageModeForGrammarAndBuffer(grammar, buffer))
          this.grammarScoresByBuffer.set(buffer, score)
        }
      }
    })
  }
}
