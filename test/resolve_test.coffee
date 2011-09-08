File   = require 'fs'
assert = require 'assert'

root = OSX.NSBundle.mainBundle.resourcePath
resolve = (path) ->
  # use a list of known load paths in the tests
  paths = require.paths
  require.paths = [ "#{root}/src", "#{root}/plugins", "#{root}/vendor" ]
  path = require.resolve path
  require.paths = paths
  path

assert.equal resolve('underscore'), "#{root}/vendor/underscore.js"
assert.equal resolve('app'), "#{root}/src/app.js"
assert.equal resolve('tabs/tabs'), "#{root}/plugins/tabs/tabs.js"

# assert.equal resolve('./document'), "#{root}/src/document.js"
# assert.equal resolve('../README.md'), "#{root}/README.md"
dotatom = File.absolute "~/.atomicity"
assert.equal resolve('~/.atomicity'), "#{dotatom}/index.coffee"

assert.equal resolve('ace/requirejs/text!ace/css/editor.css'),
  "#{root}/vendor/ace/css/editor.css"
assert.equal resolve('ace/keyboard/keybinding'),
  "#{root}/vendor/ace/keyboard/keybinding.js"
