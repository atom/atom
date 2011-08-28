# This file is the first thing loaded on startup.

console.originalLog = console.log
console.log = (thing) ->
  OSX.NSLog thing.toString() if thing?
  console.originalLog(thing)


# load require() function
root = OSX.NSBundle.mainBundle.resourcePath
code = OSX.NSString.stringWithContentsOfFile path = "#{root}/src/require.js"
__jsc__.evalJSString_withScriptPath code, path

console.log 'require tests:'
console.log require.resolve 'underscore'
console.log require.resolve 'osx'
console.log require.resolve 'ace/requirejs/text!ace/css/editor.css'
console.log require.resolve 'ace/keyboard/keybinding'
console.log '--------------'
