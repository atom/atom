###
Cache for source code transpiled by Babel.

Inspired by https://github.com/atom/atom/blob/6b963a562f8d495fbebe6abdbafbc7caf705f2c3/src/coffee-cache.coffee.
###

crypto = require 'crypto'
fs = require 'fs-plus'
path = require 'path'
babel = null # Defer until used
Grim = null # Defer until used

stats =
  hits: 0
  misses: 0

defaultOptions =
  # Currently, the cache key is a function of:
  # * The version of Babel used to transpile the .js file.
  # * The contents of this defaultOptions object.
  # * The contents of the .js file.
  # That means that we cannot allow information from an unknown source
  # to affect the cache key for the output of transpilation, which means
  # we cannot allow users to override these default options via a .babelrc
  # file, because the contents of that .babelrc file will not make it into
  # the cache key. It would be great to support .babelrc files once we
  # have a way to do so that is safe with respect to caching.
  breakConfig: true

  # The Chrome dev tools will show the original version of the file
  # when the source map is inlined.
  sourceMap: 'inline'

  # Blacklisted features do not get transpiled. Features that are
  # natively supported in the target environment should be listed
  # here. Because Atom uses a bleeding edge version of Node/io.js,
  # I think this can include es6.arrowFunctions, es6.classes, and
  # possibly others, but I want to be conservative.
  blacklist: [
    'es6.forOf'
    'useStrict'
  ]

  optional: [
    # Target a version of the regenerator runtime that
    # supports yield so the transpiled code is cleaner/smaller.
    'asyncToGenerator'
  ]

  # Includes support for es7 features listed at:
  # http://babeljs.io/docs/usage/experimental/.
  stage: 0


###
shasum - Hash with an update() method.
value - Must be a value that could be returned by JSON.parse().
###
updateDigestForJsonValue = (shasum, value) ->
  # Implmentation is similar to that of pretty-printing a JSON object, except:
  # * Strings are not escaped.
  # * No effort is made to avoid trailing commas.
  # These shortcuts should not affect the correctness of this function.
  type = typeof value
  if type is 'string'
    shasum.update('"', 'utf8')
    shasum.update(value, 'utf8')
    shasum.update('"', 'utf8')
  else if type in ['boolean', 'number']
    shasum.update(value.toString(), 'utf8')
  else if value is null
    shasum.update('null', 'utf8')
  else if Array.isArray value
    shasum.update('[', 'utf8')
    for item in value
      updateDigestForJsonValue(shasum, item)
      shasum.update(',', 'utf8')
    shasum.update(']', 'utf8')
  else
    # value must be an object: be sure to sort the keys.
    keys = Object.keys value
    keys.sort()

    shasum.update('{', 'utf8')
    for key in keys
      updateDigestForJsonValue(shasum, key)
      shasum.update(': ', 'utf8')
      updateDigestForJsonValue(shasum, value[key])
      shasum.update(',', 'utf8')
    shasum.update('}', 'utf8')

createBabelVersionAndOptionsDigest = (version, options) ->
  shasum = crypto.createHash('sha1')
  # Include the version of babel in the hash.
  shasum.update('babel-core', 'utf8')
  shasum.update('\0', 'utf8')
  shasum.update(version, 'utf8')
  shasum.update('\0', 'utf8')
  updateDigestForJsonValue(shasum, options)
  shasum.digest('hex')

cacheDir = null
jsCacheDir = null

getCachePath = (sourceCode) ->
  digest = crypto.createHash('sha1').update(sourceCode, 'utf8').digest('hex')

  unless jsCacheDir?
    to5Version = require('babel-core/package.json').version
    jsCacheDir = path.join(cacheDir, createBabelVersionAndOptionsDigest(to5Version, defaultOptions))

  path.join(jsCacheDir, "#{digest}.js")

getCachedJavaScript = (cachePath) ->
  if fs.isFileSync(cachePath)
    try
      cachedJavaScript = fs.readFileSync(cachePath, 'utf8')
      stats.hits++
      return cachedJavaScript
  null

# Returns the babel options that should be used to transpile filePath.
createOptions = (filePath) ->
  options = filename: filePath
  for key, value of defaultOptions
    options[key] = value
  options

transpile = (sourceCode, filePath, cachePath) ->
  options = createOptions(filePath)
  babel ?= require 'babel-core'
  js = babel.transform(sourceCode, options).code
  stats.misses++

  try
    fs.writeFileSync(cachePath, js)

  js

# Function that obeys the contract of an entry in the require.extensions map.
# Returns the transpiled version of the JavaScript code at filePath, which is
# either generated on the fly or pulled from cache.
loadFile = (module, filePath) ->
  sourceCode = fs.readFileSync(filePath, 'utf8')
  if sourceCode.startsWith('"use babel"') or sourceCode.startsWith("'use babel'")
    # Continue.
  else if sourceCode.startsWith('"use 6to5"') or sourceCode.startsWith("'use 6to5'")
    # Create a manual deprecation since the stack is too deep to use Grim
    # which limits the depth to 3
    Grim ?= require 'grim'
    stack = [
      {
        fileName: __filename
        functionName: 'loadFile'
        location: "#{__filename}:161:5"
      }
      {
        fileName: filePath
        functionName: '<unknown>'
        location: "#{filePath}:1:1"
      }
    ]
    deprecation =
      message: "Use the 'use babel' pragma instead of 'use 6to5'"
      stacks: [stack]
    Grim.addSerializedDeprecation(deprecation)
  else
    return module._compile(sourceCode, filePath)

  cachePath = getCachePath(sourceCode)
  js = getCachedJavaScript(cachePath) ? transpile(sourceCode, filePath, cachePath)
  module._compile(js, filePath)

register = ->
  Object.defineProperty(require.extensions, '.js', {
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
  createBabelVersionAndOptionsDigest: createBabelVersionAndOptionsDigest

  addPathToCache: (filePath) ->
    return if path.extname(filePath) isnt '.js'

    sourceCode = fs.readFileSync(filePath, 'utf8')
    cachePath = getCachePath(sourceCode)
    transpile(sourceCode, filePath, cachePath)
