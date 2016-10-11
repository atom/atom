_ = require 'underscore-plus'
FirstMate = require 'first-mate'
Token = require './token'
fs = require 'fs-plus'
Grim = require 'grim'

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
    @selectGrammarWithScore(filePath, fileContents).grammar

  selectGrammarWithScore: (filePath, fileContents) ->
    bestMatch = null
    highestScore = -Infinity
    for grammar in @grammars
      score = @getGrammarScore(grammar, filePath, fileContents)
      if score > highestScore or not bestMatch?
        bestMatch = grammar
        highestScore = score
    {grammar: bestMatch, score: highestScore}

  # Extended: Returns a {Number} representing how well the grammar matches the
  # `filePath` and `contents`.
  getGrammarScore: (grammar, filePath, contents) ->
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

    pathComponents = filePath.toLowerCase().split('/')
    pathComponents = pathComponents.concat(pathComponents.pop().split('.'))
    pathScore = -1

    fileTypes = grammar.fileTypes
    if customFileTypes = @config.get('core.customFileTypes')?[grammar.scopeName]
      fileTypes = fileTypes.concat(customFileTypes)

    for fileType, i in fileTypes
      fileTypeComponents = fileType.toLowerCase().split('/')
      fileTypeComponents = fileTypeComponents.concat(fileTypeComponents.pop().split('.'))
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

  # Deprecated: Get the grammar override for the given file path.
  #
  # * `filePath` A {String} file path.
  #
  # Returns a {String} such as `"source.js"`.
  grammarOverrideForPath: (filePath) ->
    Grim.deprecate 'Use atom.textEditors.getGrammarOverride(editor) instead'
    if editor = getEditorForPath(filePath)
      atom.textEditors.getGrammarOverride(editor)

  # Deprecated: Set the grammar override for the given file path.
  #
  # * `filePath` A non-empty {String} file path.
  # * `scopeName` A {String} such as `"source.js"`.
  #
  # Returns undefined
  setGrammarOverrideForPath: (filePath, scopeName) ->
    Grim.deprecate 'Use atom.textEditors.setGrammarOverride(editor, scopeName) instead'
    if editor = getEditorForPath(filePath)
      atom.textEditors.setGrammarOverride(editor, scopeName)
    return

  # Deprecated: Remove the grammar override for the given file path.
  #
  # * `filePath` A {String} file path.
  #
  # Returns undefined.
  clearGrammarOverrideForPath: (filePath) ->
    Grim.deprecate 'Use atom.textEditors.clearGrammarOverride(editor) instead'
    if editor = getEditorForPath(filePath)
      atom.textEditors.clearGrammarOverride(editor)
    return

getEditorForPath = (filePath) ->
  if filePath?
    atom.workspace.getTextEditors().find (editor) ->
      editor.getPath() is filePath
