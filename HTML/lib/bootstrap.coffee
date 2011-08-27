# This file is the first thing loaded on startup.

console.log = (thing) -> OSX.NSLog thing.toString()

modules = {}
this.require = (path) ->
  # hack for stupid requirejs
  if path.indexOf('ace/requirejs/text!') > -1
    path = path.replace 'ace/requirejs/text!', ''
    text = true

  return modules[path] if modules[path]

  root = OSX.NSBundle.mainBundle.resourcePath + '/HTML/'
  filename = if text then "#{root}/#{path}" else "#{root}/#{path}.js"
  file = OSX.NSString.stringWithContentsOfFile filename

  if text
    modules[path] = file.toString()
    return modules[path]

  exports = {}
  module  = exports: exports

  src  = "function define(cb){cb.call(this,require,exports)};"
  src += """(function(exports, define, module){
    #{file}
  }).call(exports, exports, define, module);
  """
  eval src

  modules[path] = module.exports or exports
  modules[path]

this.require.nameToUrl = (path) -> "#{path}.js"

this._ = require 'vendor/underscore'
