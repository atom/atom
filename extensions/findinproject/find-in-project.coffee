_ = require 'underscore'
fs = require 'fs'

ChildProcess = require 'child-process'
Extension = require 'extension'
ModalSelector = require 'modal-selector'

module.exports =
class FindInProject extends Extension
  constructor: ->
    atom.on 'project:open', @startup

  startup: (@project) =>

  query: ->
    return if not @project
    @findInProject (prompt "Find in project:"), (results) =>
      @pane = new ModalSelector -> results
      @pane.show()

  findInProject: (term, callback) ->
    root = @project.url
    ChildProcess.exec "ack --ignore-dir=Cocoa/build --ignore-dir=vendor #{term} #{@project.url}", (error, stdout, stderr) ->
      callback _.map (stdout.split "\n"), (line) ->
        name: line.replace root, ''
        url: _.first line.split ":"
