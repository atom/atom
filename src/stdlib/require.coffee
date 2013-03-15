paths = [
  "#{window.resourcePath}/spec"
  "#{window.resourcePath}/benchmark"
  "#{window.resourcePath}/src/stdlib"
  "#{window.resourcePath}/src/app"
  "#{window.resourcePath}/src/packages"
  "#{window.resourcePath}/src"
  "#{window.resourcePath}/vendor/packages"
  "#{window.resourcePath}/vendor"
  "#{window.resourcePath}/static"
  "#{window.resourcePath}/themes"
  "#{window.resourcePath}"
]

window.__filename = null

nakedLoad = (file) ->
  file = resolve file
  code = __read file
  window.eval(code + "\n//@ sourceURL=" + file)

require = (path, cb) ->
  return cb require path if cb?

  unless file = resolve(path)
    throw new Error("Require can't find file at path '#{path}'")

  ext = file.split('.').pop()

  if __moduleExists file
    if not __modules.loaded[file.toLowerCase()]?
      console.warn "Circular require: #{window.__filename} required #{file}"
    return __modules[file]
  else if __modules.loaded[file.toLowerCase()]
    console.warn "Multiple requires (different cases) for #{file}"

  [ previousFilename, window.__filename ] = [ window.__filename, file ]
  __modules[file] = {} # Fix for circular references
  __modules[file] = (exts[ext] or (file) -> __read file) file
  window.__filename = previousFilename
  __modules[file]

define = (cb) ->
  __defines.push ->
    exports = __modules[window.__filename] or {}
    module  = exports: exports
    cb.call exports, require, exports, module
    __modules.loaded[window.__filename.toLowerCase()] = true
    module.exports or exports

exts =
  js: (file, code) ->
    code or= __read file
    eval("define(function(require, exports, module) { 'use strict';#{code}})\n//@ sourceURL=#{file}")
    __defines.pop()?.call()
  coffee: (file) ->
    cacheFilePath = getCacheFilePath(file)
    if __exists(cacheFilePath)
      compiled = __read(cacheFilePath)
      writeToCache = false
    else
      {CoffeeScript} = require 'coffee-script'
      compiled = CoffeeScript.compile(__read(file), filename: file)
      writeToCache = true

    evaluated = exts.js(file, compiled)
    $native.write(cacheFilePath, compiled) if writeToCache
    evaluated
  less: (file) ->
    output = ""
    (new less.Parser).parse __read(file), (e, tree) ->
      throw new Error(e.message, file, e.line) if e
      output = tree.toCSS()
    output


getPath = (path) ->
  path = resolve(path)
  return path unless path.split('.').pop() is 'coffee'

  cacheFilePath = getCacheFilePath(path)
  unless __exists(cacheFilePath)
    {CoffeeScript} = require 'coffee-script'
    compiled = CoffeeScript.compile(__read(path), filename: path)
    $native.write(cacheFilePath, compiled)
  cacheFilePath

getCacheFilePath = (path) ->
  "/tmp/atom-compiled-scripts/#{$native.md5ForPath(path)}"

resolve = (name, {verifyExistence}={}) ->
  verifyExistence ?= true
  file = name
  if /!/.test file
    file = file.split('!').pop()

  if file[0..1] is './'
    prefix = window.__filename.split('/')[0..-2].join '/'
    file = file.replace './', "#{prefix}/"

  if file[0..2] is '../'
    prefix = window.__filename.split('/')[0..-3].join '/'
    file = file.replace '../', "#{prefix}/"

  if file[0] isnt '/'
    moduleAlreadyLoaded = paths.some (path) ->
      if __moduleExists "#{path}/#{file}"
        file = "#{path}/#{file}"
      else if __moduleExists "#{path}/#{file}.js"
        file = "#{path}/#{file}.js"
      else if expanded = __moduleExpand "#{path}/#{file}"
        file = expanded

    if not moduleAlreadyLoaded
      hasExtension = /\.(.+)$/.test(file)
      paths.some (path) ->
        fileExists = hasExtension and __exists "#{path}/#{file}"
        jsFileExists = not hasExtension and __exists "#{path}/#{file}.js"

        if jsFileExists
          file = "#{path}/#{file}.js"
        else if fileExists
          file = "#{path}/#{file}"
        else if expanded = __expand "#{path}/#{file}"
          file = expanded
  else
    file = __expand(file) or file

  if file[0] == '/'
    file
  else
    console.warn("Failed to resolve '#{name}'") if verifyExistence
    null

__moduleExists = (path) ->
  __modules[path]?

__moduleExpand = (path) ->
  return path if __moduleExists path
  for ext, handler of exts
    return "#{path}.#{ext}" if __moduleExists "#{path}.#{ext}"
    return "#{path}/index.#{ext}" if __moduleExists "#{path}/index.#{ext}"
  null

__expand = (path) ->
  modulePath = __moduleExpand path
  return modulePath if modulePath

  return path if __isFile path
  for ext, handler of exts
    return "#{path}.#{ext}" if __exists "#{path}.#{ext}"
    return "#{path}/index.#{ext}" if __exists "#{path}/index.#{ext}"

  return path if __exists path
  null

__exists = (path) ->
  $native.exists path

__isFile = (path) ->
  $native.isFile path

__read = (path) ->
  try
    $native.read(path)
  catch e
    console.error "Failed to read `#{path}`"
    throw e

__modules = { loaded : {} }
__defines = []

this.require = require
this.nakedLoad = nakedLoad
this.define  = define

this.require.paths = paths
this.require.getPath = getPath
this.require.exts  = exts

this.require.resolve   = resolve
this.require.nameToUrl = (path) -> "#{path}.js"
this.require.__modules = __modules

# issue #17
this.require.noWorker = true
