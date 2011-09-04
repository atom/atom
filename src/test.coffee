# TODO: turn these into real unit tests
OSX.NSLog 'require tests:'
OSX.NSLog require.resolve 'underscore'
OSX.NSLog require.resolve 'app'
OSX.NSLog require.resolve 'tabs/tabs'

[ fn, window.__filename ] = [ __filename, "#{root}/src/bootstrap.js" ]
OSX.NSLog require.resolve './document'
OSX.NSLog require.resolve '../README.md'
window.__filename = fn

OSX.NSLog require.resolve '~/.atomicity'
OSX.NSLog require.resolve 'ace/requirejs/text!ace/css/editor.css'
OSX.NSLog require.resolve 'ace/keyboard/keybinding'
OSX.NSLog '--------------'
