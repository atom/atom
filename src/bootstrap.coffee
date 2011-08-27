# This file is the first thing loaded on startup.

console.log = (thing) -> OSX.NSLog thing.toString()

modules = {}
paths = ['src', 'vendor']
read = (path) ->
  OSX.NSString.stringWithContentsOfFile path
this.require = (file) ->
  # hack for stupid requirejs
  if file.indexOf('ace/requirejs/text!') > -1
    file = file.replace 'ace/requirejs/text!', ''
    text = true

  return modules[file] if modules[file]

  code = null
  if file[0] is '/'
    code = read("#{file}.js") or read("#{file}/index.js")
  else
    root = OSX.NSBundle.mainBundle.resourcePath
    paths.forEach (path) ->
      return code if code
      if text
        code = read "#{root}/#{path}/#{file}"
      else
        code = read("#{root}/#{path}/#{file}.js") or
               read("#{root}/#{path}/#{file}/index.js")

  if text
    modules[file] = code.toString()
    return modules[file]

  exports = {}
  module  = exports: exports

  src  = "function define(cb){cb.call(this,require,exports)};"
  src += """(function(exports, define, module){
    #{code}
  }).call(exports, exports, define, module);
  """
  eval src

  modules[file] = module.exports or exports
  modules[file]

this.require.paths = paths

this.require.nameToUrl = (path) -> "#{path}.js"

this._ = require 'underscore'
