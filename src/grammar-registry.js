const _ = require('underscore-plus')
const Grim = require('grim')
const CSON = require('season')
const FirstMate = require('first-mate')
const {Disposable, CompositeDisposable} = require('event-kit')
const TextMateLanguageMode = require('./text-mate-language-mode')
const TreeSitterLanguageMode = require('./tree-sitter-language-mode')
const TreeSitterGrammar = require('./tree-sitter-grammar')
const Token = require('./token')
const fs = require('fs-plus')
const {Point, Range} = require('text-buffer')

const GRAMMAR_TYPE_BONUS = 1000
const PATH_SPLIT_REGEX = new RegExp('[/.]')

// Extended: This class holds the grammars used for tokenizing.
//
// An instance of this class is always available as the `atom.grammars` global.
module.exports =
class GrammarRegistry {
  constructor ({config} = {}) {
    this.config = config
    this.subscriptions = new CompositeDisposable()
    this.textmateRegistry = new FirstMate.GrammarRegistry({maxTokensPerLine: 100, maxLineLength: 1000})
    this.clear()
  }

  clear () {
    this.textmateRegistry.clear()
    this.treeSitterGrammarsById = {}
    if (this.subscriptions) this.subscriptions.dispose()
    this.subscriptions = new CompositeDisposable()
    this.languageOverridesByBufferId = new Map()
    this.grammarScoresByBuffer = new Map()
    this.textMateScopeNamesByTreeSitterLanguageId = new Map()
    this.treeSitterLanguageIdsByTextMateScopeName = new Map()

    const grammarAddedOrUpdated = this.grammarAddedOrUpdated.bind(this)
    this.textmateRegistry.onDidAddGrammar(grammarAddedOrUpdated)
    this.textmateRegistry.onDidUpdateGrammar(grammarAddedOrUpdated)
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
  // * `buffer` The {TextBuffer} whose grammar will be set.
  // * `languageId` The {String} id of the desired language.
  //
  // Returns a {Boolean} that indicates whether the language was successfully
  // found.
  assignLanguageMode (buffer, languageId) {
    if (buffer.getBuffer) buffer = buffer.getBuffer()
    languageId = this.normalizeLanguageId(languageId)

    let grammar = null
    if (languageId != null) {
      grammar = this.grammarForId(languageId)
      if (!grammar) return false
      this.languageOverridesByBufferId.set(buffer.id, languageId)
    } else {
      this.languageOverridesByBufferId.set(buffer.id, null)
      grammar = this.textmateRegistry.nullGrammar
    }

    this.grammarScoresByBuffer.set(buffer, null)
    if (grammar.scopeName !== buffer.getLanguageMode().getLanguageId()) {
      buffer.setLanguageMode(this.languageModeForGrammarAndBuffer(grammar, buffer))
    }

    return true
  }

  // Extended: Get the `languageId` that has been explicitly assigned to
  // to the given buffer, if any.
  //
  // Returns a {String} id of the language
  getAssignedLanguageId (buffer) {
    return this.languageOverridesByBufferId.get(buffer.id)
  }

  // Extended: Remove any language mode override that has been set for the
  // given {TextBuffer}. This will assign to the buffer the best language
  // mode available.
  //
  // * `buffer` The {TextBuffer}.
  autoAssignLanguageMode (buffer) {
    const result = this.selectGrammarWithScore(
      buffer.getPath(),
      getGrammarSelectionContent(buffer)
    )
    this.languageOverridesByBufferId.delete(buffer.id)
    this.grammarScoresByBuffer.set(buffer, result.score)
    if (result.grammar.scopeName !== buffer.getLanguageMode().getLanguageId()) {
      buffer.setLanguageMode(this.languageModeForGrammarAndBuffer(result.grammar, buffer))
    }
  }

  languageModeForGrammarAndBuffer (grammar, buffer) {
    if (grammar instanceof TreeSitterGrammar) {
      return new TreeSitterLanguageMode({grammar, buffer, config: this.config})
    } else {
      return new TextMateLanguageMode({grammar, buffer, config: this.config})
    }
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
    this.forEachGrammar(grammar => {
      const score = this.getGrammarScore(grammar, filePath, fileContents)
      if (score > highestScore || bestMatch == null) {
        bestMatch = grammar
        highestScore = score
      }
    })
    return {grammar: bestMatch, score: highestScore}
  }

  // Extended: Returns a {Number} representing how well the grammar matches the
  // `filePath` and `contents`.
  getGrammarScore (grammar, filePath, contents) {
    if (contents == null && fs.isFileSync(filePath)) {
      contents = fs.readFileSync(filePath, 'utf8')
    }

    let score = this.getGrammarPathScore(grammar, filePath)
    if (score > 0 && !grammar.bundledPackage) {
      score += 0.125
    }
    if (this.grammarMatchesContents(grammar, contents)) {
      score += 0.25
    }

    if (score > 0 && this.isGrammarPreferredType(grammar)) {
      score += GRAMMAR_TYPE_BONUS
    }

    return score
  }

  getGrammarPathScore (grammar, filePath) {
    if (!filePath) return -1
    if (process.platform === 'win32') { filePath = filePath.replace(/\\/g, '/') }

    const pathComponents = filePath.toLowerCase().split(PATH_SPLIT_REGEX)
    let pathScore = 0

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
    if (contents == null) return false

    if (grammar.contentRegExp) { // TreeSitter grammars
      return grammar.contentRegExp.test(contents)
    } else if (grammar.firstLineRegex) { // FirstMate grammars
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
    } else {
      return false
    }
  }

  forEachGrammar (callback) {
    this.textmateRegistry.grammars.forEach(callback)
    for (let grammarId in this.treeSitterGrammarsById) {
      callback(this.treeSitterGrammarsById[grammarId])
    }
  }

  grammarForId (languageId) {
    languageId = this.normalizeLanguageId(languageId)

    return (
      this.textmateRegistry.grammarForScopeName(languageId) ||
      this.treeSitterGrammarsById[languageId]
    )
  }

  // Deprecated: Get the grammar override for the given file path.
  //
  // * `filePath` A {String} file path.
  //
  // Returns a {String} such as `"source.js"`.
  grammarOverrideForPath (filePath) {
    Grim.deprecate('Use buffer.getLanguageMode().getLanguageId() instead')
    const buffer = atom.project.findBufferForPath(filePath)
    if (buffer) return this.getAssignedLanguageId(buffer)
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
    if (grammar.scopeName && !grammar.id) grammar.id = grammar.scopeName

    this.grammarScoresByBuffer.forEach((score, buffer) => {
      const languageMode = buffer.getLanguageMode()
      if (grammar.injectionSelector) {
        if (languageMode.hasTokenForSelector(grammar.injectionSelector)) {
          languageMode.retokenizeLines()
        }
        return
      }

      const languageOverride = this.languageOverridesByBufferId.get(buffer.id)

      if ((grammar.id === buffer.getLanguageMode().getLanguageId() ||
           grammar.id === languageOverride)) {
        buffer.setLanguageMode(this.languageModeForGrammarAndBuffer(grammar, buffer))
      } else if (!languageOverride) {
        const score = this.getGrammarScore(grammar, buffer.getPath(), getGrammarSelectionContent(buffer))
        const currentScore = this.grammarScoresByBuffer.get(buffer)
        if (currentScore == null || score > currentScore) {
          buffer.setLanguageMode(this.languageModeForGrammarAndBuffer(grammar, buffer))
          this.grammarScoresByBuffer.set(buffer, score)
        }
      }
    })
  }

  // Extended: Invoke the given callback when a grammar is added to the registry.
  //
  // * `callback` {Function} to call when a grammar is added.
  //   * `grammar` {Grammar} that was added.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidAddGrammar (callback) {
    return this.textmateRegistry.onDidAddGrammar(callback)
  }

  // Extended: Invoke the given callback when a grammar is updated due to a grammar
  // it depends on being added or removed from the registry.
  //
  // * `callback` {Function} to call when a grammar is updated.
  //   * `grammar` {Grammar} that was updated.
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidUpdateGrammar (callback) {
    return this.textmateRegistry.onDidUpdateGrammar(callback)
  }

  get nullGrammar () {
    return this.textmateRegistry.nullGrammar
  }

  get grammars () {
    return this.textmateRegistry.grammars
  }

  decodeTokens () {
    return this.textmateRegistry.decodeTokens.apply(this.textmateRegistry, arguments)
  }

  grammarForScopeName (scopeName) {
    return this.grammarForId(scopeName)
  }

  addGrammar (grammar) {
    if (grammar instanceof TreeSitterGrammar) {
      this.treeSitterGrammarsById[grammar.id] = grammar
      if (grammar.legacyScopeName) {
        this.config.setLegacyScopeAliasForNewScope(grammar.id, grammar.legacyScopeName)
        this.textMateScopeNamesByTreeSitterLanguageId.set(grammar.id, grammar.legacyScopeName)
        this.treeSitterLanguageIdsByTextMateScopeName.set(grammar.legacyScopeName, grammar.id)
      }
      this.grammarAddedOrUpdated(grammar)
      return new Disposable(() => this.removeGrammar(grammar))
    } else {
      return this.textmateRegistry.addGrammar(grammar)
    }
  }

  removeGrammar (grammar) {
    if (grammar instanceof TreeSitterGrammar) {
      delete this.treeSitterGrammarsById[grammar.id]
      if (grammar.legacyScopeName) {
        this.config.removeLegacyScopeAliasForNewScope(grammar.id)
        this.textMateScopeNamesByTreeSitterLanguageId.delete(grammar.id)
        this.treeSitterLanguageIdsByTextMateScopeName.delete(grammar.legacyScopeName)
      }
    } else {
      return this.textmateRegistry.removeGrammar(grammar)
    }
  }

  removeGrammarForScopeName (scopeName) {
    return this.textmateRegistry.removeGrammarForScopeName(scopeName)
  }

  // Extended: Read a grammar asynchronously and add it to the registry.
  //
  // * `grammarPath` A {String} absolute file path to a grammar file.
  // * `callback` A {Function} to call when loaded with the following arguments:
  //   * `error` An {Error}, may be null.
  //   * `grammar` A {Grammar} or null if an error occured.
  loadGrammar (grammarPath, callback) {
    this.readGrammar(grammarPath, (error, grammar) => {
      if (error) return callback(error)
      this.addGrammar(grammar)
      callback(null, grammar)
    })
  }

  // Extended: Read a grammar synchronously and add it to this registry.
  //
  // * `grammarPath` A {String} absolute file path to a grammar file.
  //
  // Returns a {Grammar}.
  loadGrammarSync (grammarPath) {
    const grammar = this.readGrammarSync(grammarPath)
    this.addGrammar(grammar)
    return grammar
  }

  // Extended: Read a grammar asynchronously but don't add it to the registry.
  //
  // * `grammarPath` A {String} absolute file path to a grammar file.
  // * `callback` A {Function} to call when read with the following arguments:
  //   * `error` An {Error}, may be null.
  //   * `grammar` A {Grammar} or null if an error occured.
  //
  // Returns undefined.
  readGrammar (grammarPath, callback) {
    if (!callback) callback = () => {}
    CSON.readFile(grammarPath, (error, params = {}) => {
      if (error) return callback(error)
      try {
        callback(null, this.createGrammar(grammarPath, params))
      } catch (error) {
        callback(error)
      }
    })
  }

  // Extended: Read a grammar synchronously but don't add it to the registry.
  //
  // * `grammarPath` A {String} absolute file path to a grammar file.
  //
  // Returns a {Grammar}.
  readGrammarSync (grammarPath) {
    return this.createGrammar(grammarPath, CSON.readFileSync(grammarPath) || {})
  }

  createGrammar (grammarPath, params) {
    if (params.type === 'tree-sitter') {
      return new TreeSitterGrammar(this, grammarPath, params)
    } else {
      if (typeof params.scopeName !== 'string' || params.scopeName.length === 0) {
        throw new Error(`Grammar missing required scopeName property: ${grammarPath}`)
      }
      return this.textmateRegistry.createGrammar(grammarPath, params)
    }
  }

  // Extended: Get all the grammars in this registry.
  //
  // Returns a non-empty {Array} of {Grammar} instances.
  getGrammars () {
    return this.textmateRegistry.getGrammars()
  }

  scopeForId (id) {
    return this.textmateRegistry.scopeForId(id)
  }

  isGrammarPreferredType (grammar) {
    return this.config.get('core.useTreeSitterParsers')
      ? grammar instanceof TreeSitterGrammar
      : grammar instanceof FirstMate.Grammar
  }

  normalizeLanguageId (languageId) {
    if (this.config.get('core.useTreeSitterParsers')) {
      return this.treeSitterLanguageIdsByTextMateScopeName.get(languageId) || languageId
    } else {
      return this.textMateScopeNamesByTreeSitterLanguageId.get(languageId) || languageId
    }
  }
}

function getGrammarSelectionContent (buffer) {
  return buffer.getTextInRange(Range(
    Point(0, 0),
    buffer.positionForCharacterIndex(1024)
  ))
}
