nakedLoad 'jasmine-jquery'
$ = require 'jquery'
_ = require 'underscore'
Native = require 'native'

afterEach ->
  (new Native).resetMainMenu()

window.atom = new (require 'app')

window.keypressEvent = (pattern, properties={}) ->
  $.Event "keypress", _.extend(atom.keyBinder.parseKeyPattern(pattern), properties)

window.keydownEvent = (pattern, properties={}) ->
  $.Event "keydown", _.extend(atom.keyBinder.parseKeyPattern(pattern), properties)

window.waitsForPromise = (fn) ->
  window.waitsFor (moveOn) ->
    fn().done(moveOn)

