resourcePath = OSX.NSBundle.mainBundle.resourcePath

paths = [
  "/Users/chris/Code/Atomicity/src",
  "/Users/chris/Code/Atomicity/plugins",

  "#{resourcePath}/src",
  "#{resourcePath}/plugins",
  "#{resourcePath}/vendor"
]

window.__filename = null

require = (file, cb) ->
  return cb require file if cb?

  file  = resolve file
  parts = file.split '.'
  ext   = parts[parts.length-1]

  return __modules[file] if __modules[file]?

  [ previousFilename, window.__filename ] = [ __filename, file ]
  __modules[file] = {} # Fix for circular references
  __modules[file] = (exts[ext] or (file) -> __read file) file
  window.__filename = previousFilename
  __modules[file]

define  = (cb) ->
  __defines.push ->
    exports = __modules[__filename] or {}
    module  = exports: exports
    cb.call exports, require, exports, module
    module.exports or exports

exts =
  js: (file, code) ->
    code or= __read file

    if not /define\(/.test code
      code = """
        define(function(require, exports, module) {
          #{code};
        });
      """
    __jsc__.evalJSString_withScriptPath code, file
    __defines.pop()?.call()
  coffee: (file) ->
    {CoffeeScript} = require 'coffee-script'
    exts.js file, CoffeeScript.compile __read file

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
    paths.some (path) ->
      if /\.(.+)$/.test(file) and __exists "#{path}/#{file}"
        file = "#{path}/#{file}"
      else if expanded = expandPath "#{path}/#{file}"
        file = expanded
  else
    file = expandPath(file) or file

  if file[0] isnt '/'
    throw "require: Can't find '#{file}'"

  return file

expandPath = (path) ->
  for ext, handler of exts
    if __exists "#{path}.#{ext}"
      return "#{path}.#{ext}"
    else if __exists "#{path}/index.#{ext}"
      return "#{path}/index.#{ext}"

  return null

__exists = (path) ->
  OSX.NSFileManager.defaultManager.fileExistsAtPath path

__read = (path) ->
  try
    OSX.NSString.stringWithContentsOfFile(path).toString()
  catch e
    throw "require: can't read #{path}"

__modules = {}
__defines = []


this.require = require
this.define  = define

this.require.paths = paths
this.require.exts  = exts

this.require.resolve   = resolve
this.require.nameToUrl = (path) -> "#{path}.js"
this.require.__modules = __modules
