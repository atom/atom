paths = [
  "#{atom.loadPath}/spec"
  "#{atom.loadPath}/src/stdlib"
  "#{atom.loadPath}/src/atom"
  "#{atom.loadPath}/src"
  "#{atom.loadPath}/extensions"
  "#{atom.loadPath}/vendor"
  "#{atom.loadPath}/static"
]

window.__filename = null

nakedLoad = (file) ->
  file = resolve file
  code = __read file
  window.eval(code + "\n//@ sourceURL=" + file)

require = (file, cb) ->
  return cb require file if cb?

  file  = resolve file
  parts = file.split '.'
  ext   = parts[parts.length-1]

  if __modules[file]?
    if not __modules.loaded[file.toLowerCase()]?
      console.warn "Circular require: #{__filename} required #{file}"
    return __modules[file]
  else if __modules.loaded[file.toLowerCase()]
    console.warn "Multiple requires (different cases) for #{file}"

  [ previousFilename, window.__filename ] = [ __filename, file ]
  __modules[file] = {} # Fix for circular references
  __modules[file] = (exts[ext] or (file) -> __read file) file
  window.__filename = previousFilename
  __modules[file]

define = (cb) ->
  __defines.push ->
    exports = __modules[__filename] or {}
    module  = exports: exports
    cb.call exports, require, exports, module
    __modules.loaded[__filename.toLowerCase()] = true
    module.exports or exports

exts =
  js: (file, code) ->
    code or= __read file

    if not /define\(/.test code
      code = """
        define(function(require, exports, module) { 'use strict'; #{code};
        });
      """
    eval(code + "\n//@ sourceURL=" + file)
    __defines.pop()?.call()
  coffee: (file) ->
    exts.js(file, __coffeeCache(file))

resolve = (file) ->
  if /!/.test file
    parts = file.split '!'
    file = parts[parts.length-1]

  if file[0..1] is './'
    prefix = __filename.split('/')[0..-2].join '/'
    file = file.replace './', "#{prefix}/"

  if file[0..2] is '../'
    prefix = __filename.split('/')[0..-3].join '/'
    file = file.replace '../', "#{prefix}/"

  if file[0] isnt '/'
    paths.some (path) ->
      fileExists = /\.(.+)$/.test(file) and __exists "#{path}/#{file}"
      jsFileExists = not /\.(.+)$/.test(file) and __exists "#{path}/#{file}.js"

      if fileExists
        file = "#{path}/#{file}"
      if jsFileExists
        file = "#{path}/#{file}.js"
      else if expanded = __expand "#{path}/#{file}"
        file = expanded
  else
    file = __expand(file) or file

  if file[0] isnt '/'
    throw "require: Can't find '#{file}'"

  return file

__expand = (path) ->
  for ext, handler of exts
    if __exists "#{path}.#{ext}"
      return "#{path}.#{ext}"
    else if __exists "#{path}/index.#{ext}"
      return "#{path}/index.#{ext}"

  return path if __exists path
  return null

__exists = (path) ->
  atom.native.exists path

__coffeeCache = (filePath) ->
  {CoffeeScript} = require 'coffee-script'
  CoffeeScript.compile(__read(filePath), filename: filePath)

__read = (path) ->
  try
    atom.native.read(path)
  catch e
    throw "require: can't read #{path}"

__modules = { loaded : {} }
__defines = []

this.require = require
this.nakedLoad = nakedLoad
this.define  = define

this.require.paths = paths
this.require.exts  = exts

this.require.resolve   = resolve
this.require.nameToUrl = (path) -> "#{path}.js"
this.require.__modules = __modules

# issue #17
this.require.noWorker = true
