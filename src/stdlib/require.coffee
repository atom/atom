# Hack to get code reloading working in dev mode
resourcePath = $atomController.projectPath ? OSX.NSBundle.mainBundle.resourcePath

paths = [
  "#{resourcePath}/spec"
  "#{resourcePath}/src/stdlib"
  "#{resourcePath}/src/atom"
  "#{resourcePath}/src"
  "#{resourcePath}/extensions"
  "#{resourcePath}/vendor"
]

window.__filename = null

nakedLoad = (file) ->
  file = resolve file
  code = __read file
  __jsc__.evalJSString_withScriptPath code, file

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
    __jsc__.evalJSString_withScriptPath code, file
    __defines.pop()?.call()
  coffee: (file) ->
    {CoffeeScript} = require 'coffee-script'
    exts.js(file, CoffeeScript.compile(__read(file), filename: file))

resolve = (file) ->
  if /!/.test file
    parts = file.split '!'
    file = parts[parts.length-1]

  if file[0] is '~'
    file = OSX.NSString.stringWithString(file)
      .stringByExpandingTildeInPath.toString()

  if file[0..1] is './'
    prefix = __filename.split('/')[0..-2].join '/'
    file = file.replace './', "#{prefix}/"

  if file[0..2] is '../'
    prefix = __filename.split('/')[0..-3].join '/'
    file = file.replace '../', "#{prefix}/"

  if file[0] isnt '/'
    require.paths.some (path) ->
      if /\.(.+)$/.test(file) and __exists "#{path}/#{file}"
        file = "#{path}/#{file}"
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
  OSX.NSFileManager.defaultManager.fileExistsAtPath path

__read = (path) ->
  try
    OSX.NSString.stringWithContentsOfFile(path).toString()
  catch e
    throw "require: can't read #{path}"

__modules = { loaded : {} }
__defines = []

this.require = require
this.nakedLoad = nakedLoad
this.define  = define

this.require.resourcePath = resourcePath
this.require.paths = paths
this.require.exts  = exts

this.require.resolve   = resolve
this.require.nameToUrl = (path) -> "#{path}.js"
this.require.__modules = __modules

# issue #17
this.require.noWorker = true
