# This file is the first thing loaded on startup.

console.log = (thing) -> OSX.NSLog thing.toString() if thing?

# load require() function
root = OSX.NSBundle.mainBundle.resourcePath
code = OSX.NSString.stringWithContentsOfFile "#{root}/src/require.js"
eval "(function(){ #{code} })(this);"

console.log 'require tests:'
console.log require.resolve 'underscore'
console.log require.resolve 'osx'
console.log require.resolve 'ace/requirejs/text!ace/css/editor.css'
console.log require.resolve 'ace/keyboard/keybinding'

this._ = require 'underscore'
