path = require 'path'
fs = require 'fs-plus'
GrammarRegistry = require '../../src/grammar-registry'
TokenizedBuffer = require '../../src/tokenized-buffer'
TextBuffer = require 'text-buffer'
{config, packageManager, assert} = require './mocks'

removeMiddle = (string, length) ->
  edgeLength = Math.round(length/2)
  if length >= string.length
    return string
  string.slice(0,edgeLength) + string.slice(string.length-edgeLength,string.length)

loadGrammar = (registry, packageName) ->
  nodeModulesPath = path.join(__dirname, '../../node_modules')
  packagePath = path.join(nodeModulesPath, packageName)
  grammarsPath = path.join(packagePath, 'grammars')
  grammarFiles = fs.readdirSync(grammarsPath)
  grammarFiles.filter (grammarFile) ->
    grammarFile.match(/.cson$/)
  .forEach (grammarFile) ->
    grammarPath = path.join(grammarsPath, grammarFile)
    registry.loadGrammarSync(grammarPath)

tokenizeFile = (grammarRegistry, filePath, characterCount) ->
  buffer = new TextBuffer({filePath})
  buffer.loadSync()
  buffer.lines.forEach (line, index) ->
    if line.length > characterCount
      buffer.lines[index] = removeMiddle line, characterCount

  tokenizedBuffer = new TokenizedBuffer({
    buffer, ignoreInvisibles: false, largeFileMode: false, config,
    grammarRegistry, packageManager, assert
  })
  start = Date.now()
  tokenizedBuffer.setVisible true

  new Promise (resolve) ->
    tokenizedBuffer.onDidTokenize (callback) ->
      duration = Date.now() - start
      console.log "fully tokenized #{characterCount} characters in #{duration}ms"
      resolve()

registry = new GrammarRegistry({config})
registry.maxLineLength = Infinity
grammarPackages = ['language-html', 'language-javascript']
grammarPackages.forEach (grammarPackage) ->
  loadGrammar(registry, grammarPackage)

grammarPath = path.join(__dirname, 'long.html')
tokenizeFile(registry, grammarPath, 1000)
.then -> tokenizeFile(registry, grammarPath, 2000)
.then -> tokenizeFile(registry, grammarPath, 4000)
.then -> tokenizeFile(registry, grammarPath, 8000)
.then -> tokenizeFile(registry, grammarPath, 20000)
.then -> process.exit()
