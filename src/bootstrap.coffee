# This file is the first thing loaded on startup.

# load require() function
root = OSX.NSBundle.mainBundle.resourcePath
code = OSX.NSString.stringWithContentsOfFile path = "#{root}/src/require.js"
__jsc__.evalJSString_withScriptPath code, path

# TODO: turn these into real unit tests
OSX.NSLog 'require tests:'
OSX.NSLog require.resolve 'underscore'
OSX.NSLog require.resolve 'osx'
OSX.NSLog require.resolve 'tabs/tabs'

[ fn, window.__filename ] = [ __filename, "#{root}/src/bootstrap.js" ]
OSX.NSLog require.resolve './document'
OSX.NSLog require.resolve '../README.md'
window.__filename = fn

OSX.NSLog require.resolve '~/.atomicity'
OSX.NSLog require.resolve 'ace/requirejs/text!ace/css/editor.css'
OSX.NSLog require.resolve 'ace/keyboard/keybinding'
OSX.NSLog '--------------'
