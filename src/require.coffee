resourcePath = OSX.NSBundle.mainBundle.resourcePath

paths = [
  "#{resourcePath}/src",
  "#{resourcePath}/plugins",
  "#{resourcePath}/vendor"
]

require = (file) ->
  file  = resolve file
  parts = file.split '.'
  ext   = parts[parts.length-1]

  return __modules[file] if __modules[file]?

  __modules[file] = {} # Fix for circular references
  __modules[file] = exts[ext]? file
  __modules[file]

exts =
  css: (file) -> __read file
  js:  (file) ->
    code    = __read file
    exports = {}
    module  = exports: exports

    src  = "function define(cb){cb.call(this,require,exports)};"
    src += """(function(exports, define, module){
      #{code}
      /*close open comments*/
    }).call(exports, exports, define, module);
    """
    eval src

    module.exports or exports

resolve = (file) ->
  if /!/.test file
    parts = file.split '!'
    file = parts[parts.length-1]

  if file[0..1] is './'
    throw "require: ./ prefix not yet implemented"

  if file[0..2] is '../'
    throw "require: ../ prefix not yet implemented"

  if file[0] isnt '/'
    # I want to use _.detect, but we don't have that at this point
    # or break would do, but coffeescript doesn't have that
    expandedPath = null
    paths.forEach (path) ->
      if /\.(.+)$/.test(file) and __exists "#{path}/#{file}"
        expandedPath ?= "#{path}/#{file}"
      else
        expandedPath ?= expandPath("#{path}/#{file}")

      file = expandedPath if expandedPath?
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
  OSX.NSString.stringWithContentsOfFile path

__modules = {}


this.require = require

this.require.paths = paths
this.require.exts  = exts

this.require.resolve   = resolve
this.require.nameToUrl = (path) -> "#{path}.js"
