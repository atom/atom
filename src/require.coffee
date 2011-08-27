resourcePath = OSX.NSBundle.mainBundle.resourcePath

paths = [
  "#{resourcePath}/src",
  "#{resourcePath}/plugins",
  "#{resourcePath}/vendor"
]

require = (file) ->
  return __modules[file] if __modules[file]?

  file  = resolve file
  parts = file.split '.'
  ext   = parts[parts.length-1]

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
    paths.forEach (path) ->
      if /\.(.+)$/.test(file) and __exists "#{path}/#{file}"
        file = "#{path}/#{file}"
      else
        for ext, handler of exts
          if __exists "#{path}/#{file}.#{ext}"
            file = "#{path}/#{file}.#{ext}"
          else if __exists "#{path}/#{file}/index.#{ext}"
            file = "#{path}/#{file}/index.#{ext}"

  if file[0] isnt '/'
    throw "require: Can't find '#{file}'"

  return file


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
