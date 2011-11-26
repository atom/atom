fs   = require 'fs'
assert = require 'assert'

root = OSX.NSBundle.mainBundle.resourcePath
resolve = (path) ->
  # use a list of known load paths in the tests
  paths = require.paths
  require.paths = [ "#{root}/src", "#{root}/extensions", "#{root}/vendor" ]
  path = require.resolve path
  require.paths = paths
  path

assert.equal resolve('underscore'), "#{root}/vendor/underscore.js"
assert.equal resolve('atom/window'), "#{root}/src/atom/window.js"
assert.equal resolve('tabs/tabs'), "#{root}/extensions/tabs/tabs.js"

#assert.equal resolve('./resource'), "#{root}/src/resource.js"
#assert.equal resolve('../README.md'), "#{root}/README.md"

dotatom = fs.absolute "~/.atom"
assert.equal resolve('~/.atom'), "#{dotatom}/index.coffee"

assert.equal resolve('ace/requirejs/text!ace/css/editor.css'),
  "#{root}/vendor/ace/css/editor.css"
assert.equal resolve('ace/keyboard/keybinding'),
  "#{root}/vendor/ace/keyboard/keybinding.js"
