###
Cache for source code transpiled by TypeScript.

Inspired by https://github.com/atom/atom/blob/7a719d585db96ff7d2977db9067e1d9d4d0adf1a/src/babel.coffee
###

crypto = require 'crypto'
fs = require 'fs-plus'
path = require 'path'
tss = null # Defer until used

stats =
  hits: 0
  misses: 0

defaultOptions =
  target: 1 # ES5
  module: 'commonjs'
  sourceMap: true

createTypeScriptVersionAndOptionsDigest = (version, options) ->
  shasum = crypto.createHash('sha1')
  # Include the version of typescript in the hash.
  shasum.update('typescript', 'utf8')
  shasum.update('\0', 'utf8')
  shasum.update(version, 'utf8')
  shasum.update('\0', 'utf8')
  shasum.update(JSON.stringify(options))
  shasum.digest('hex')

cacheDir = null
jsCacheDir = null

getCachePath = (sourceCode) ->
  digest = crypto.createHash('sha1').update(sourceCode, 'utf8').digest('hex')

  unless jsCacheDir?
    tssVersion = require('typescript-simple/package.json').version
    jsCacheDir = path.join(cacheDir, createTypeScriptVersionAndOptionsDigest(tssVersion, defaultOptions))

  path.join(jsCacheDir, "#{digest}.js")

getCachedJavaScript = (cachePath) ->
  if fs.isFileSync(cachePath)
    try
      cachedJavaScript = fs.readFileSync(cachePath, 'utf8')
      stats.hits++
      return cachedJavaScript
  null

# Returns the TypeScript options that should be used to transpile filePath.
createOptions = (filePath) ->
  options = filename: filePath
  for key, value of defaultOptions
    options[key] = value
  options

transpile = (sourceCode, filePath, cachePath) ->
  options = createOptions(filePath)
  unless tss?
    {TypeScriptSimple} = require 'typescript-simple'
    tss = new TypeScriptSimple(options, false)
  js = tss.compile(sourceCode, filePath)
  stats.misses++

  try
    fs.writeFileSync(cachePath, js)

  js

# Function that obeys the contract of an entry in the require.extensions map.
# Returns the transpiled version of the JavaScript code at filePath, which is
# either generated on the fly or pulled from cache.
loadFile = (module, filePath) ->
  sourceCode = fs.readFileSync(filePath, 'utf8')
  cachePath = getCachePath(sourceCode)
  js = getCachedJavaScript(cachePath) ? transpile(sourceCode, filePath, cachePath)
  module._compile(js, filePath)

register = ->
  Object.defineProperty(require.extensions, '.ts', {
    enumerable: true
    writable: false
    value: loadFile
  })

setCacheDirectory = (newCacheDir) ->
  if cacheDir isnt newCacheDir
    cacheDir = newCacheDir
    jsCacheDir = null

module.exports =
  register: register
  setCacheDirectory: setCacheDirectory
  getCacheMisses: -> stats.misses
  getCacheHits: -> stats.hits

  # Visible for testing.
  createTypeScriptVersionAndOptionsDigest: createTypeScriptVersionAndOptionsDigest

  addPathToCache: (filePath) ->
    return if path.extname(filePath) isnt '.ts'

    sourceCode = fs.readFileSync(filePath, 'utf8')
    cachePath = getCachePath(sourceCode)
    transpile(sourceCode, filePath, cachePath)
