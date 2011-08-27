# This file is the first thing loaded on startup.

modules = {}
this.require = (path) ->
  console.log(path)
  return modules[path] if modules[path]

  root = OSX.NSBundle.mainBundle.resourcePath + '/HTML/'
  file = OSX.NSString.stringWithContentsOfFile "#{root}/#{path}.js"
  exports = {}
  eval "(function(exports){#{file}}).call(exports, exports);"

  modules[path] = exports
  modules[path]

