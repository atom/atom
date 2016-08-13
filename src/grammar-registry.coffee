_ = require 'underscore-plus'
{Emitter} = require 'event-kit'
FirstMate = require 'first-mate'
Token = require './token'
fs = require 'fs-plus'

PathSplitRegex = new RegExp("[/.]")

# Extended: Syntax class holding the grammars used for tokenizing.
#
# An instance of this class is always available as the `atom.grammars` global.
#
# The Syntax class also contains properties for things such as the
# language-specific comment regexes. See {::getProperty} for more details.
module.exports =
class GrammarRegistry extends FirstMate.GrammarRegistry
  constructor: ({@config}={}) ->
    super(maxTokensPerLine: 100)

  createToken: (value, scopes) -> new Token({value, scopes})

  # Extended: Select a grammar for the given file path and file contents.
  #
  # This picks the best match by checking the file path and contents against
  # each grammar.
  #
  # * `filePath` A {String} file path.
  # * `fileContents` A {String} of text for the file path.
  #
  # Returns a {Grammar}, never null.
  selectGrammar: (filePath, fileContents) ->
    bestMatch = null
    highestScore = -Infinity
    for grammar in @grammars
      score = @getGrammarScore(grammar, filePath, fileContents)
      if score > highestScore or not bestMatch?
        bestMatch = grammar
        highestScore = score
    bestMatch

  # Extended: Returns a {Number} representing how well the grammar matches the
  # `filePath` and `contents`.
  getGrammarScore: (grammar, filePath, contents) ->
    return Infinity if @grammarOverrideForPath(filePath) is grammar.scopeName

    contents = fs.readFileSync(filePath, 'utf8') if not contents? and fs.isFileSync(filePath)

    score = @getGrammarPathScore(grammar, filePath)
    if score > 0 and not grammar.bundledPackage
      score += 0.25
    if @grammarMatchesContents(grammar, contents)
      score += 0.125
    score

  getGrammarPathScore: (grammar, filePath) ->
    return -1 unless filePath
    filePath = filePath.replace(/\\/g, '/') if process.platform is 'win32'

    pathComponents = filePath.toLowerCase().split(PathSplitRegex)
    pathScore = -1

    fileTypes = grammar.fileTypes
    if customFileTypes = @config.get('core.customFileTypes')?[grammar.scopeName]
      fileTypes = fileTypes.concat(customFileTypes)

    for fileType, i in fileTypes
      fileTypeComponents = fileType.toLowerCase().split(PathSplitRegex)
      pathSuffix = pathComponents[-fileTypeComponents.length..-1]
      if _.isEqual(pathSuffix, fileTypeComponents)
        pathScore = Math.max(pathScore, fileType.length)
        if i >= grammar.fileTypes.length
          pathScore += 0.5

    pathScore

  grammarMatchesContents: (grammar, contents) ->
    return false unless contents? and grammar.firstLineRegex?

    escaped = false
    numberOfNewlinesInRegex = 0
    for character in grammar.firstLineRegex.source
      switch character
        when '\\'
          escaped = not escaped
        when 'n'
          numberOfNewlinesInRegex++ if escaped
          escaped = false
        else
          escaped = false
    lines = contents.split('\n')
    grammar.firstLineRegex.testSync(lines[0..numberOfNewlinesInRegex].join('\n'))

  # Public: Get the grammar override for the given file path.
  #
  # * `filePath` A {String} file path.
  #
  # Returns a {Grammar} or undefined.
  grammarOverrideForPath: (filePath) ->
    @grammarOverridesByPath[filePath]

  # Public: Set the grammar override for the given file path.
  #
  # * `filePath` A non-empty {String} file path.
  # * `scopeName` A {String} such as `"source.js"`.
  #
  # Returns a {Grammar} or undefined.
  setGrammarOverrideForPath: (filePath, scopeName) ->
    if filePath
      @grammarOverridesByPath[filePath] = scopeName

  # Public: Remove the grammar override for the given file path.
  #
  # * `filePath` A {String} file path.
  #
  # Returns undefined.
  clearGrammarOverrideForPath: (filePath) ->
    delete @grammarOverridesByPath[filePath]
    undefined

  # Public: Remove all grammar overrides.
  #
  # Returns undefined.
  clearGrammarOverrides: ->
    @grammarOverridesByPath = {}
    undefined
