# This file is the first thing loaded on startup.

console.log = (thing) -> OSX.NSLog thing.toString()

modules = {}
paths = ['src', 'vendor']
this.require = (file) ->
  # hack for stupid requirejs
  if file.indexOf('ace/requirejs/text!') > -1
    file = file.replace 'ace/requirejs/text!', ''
    text = true

  return modules[file] if modules[file]

  code = null
  paths.forEach (path) ->
    return code if code
    root = OSX.NSBundle.mainBundle.resourcePath + "/#{path}"
    fullpath = if text then "#{root}/#{file}" else "#{root}/#{file}.js"
    code = OSX.NSString.stringWithContentsOfFile fullpath

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
