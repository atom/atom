Point = require 'point'
ChildProcess = nodeRequire 'child_process'
$ = require 'jquery'
BufferedProcess = require 'buffered-process'

module.exports =
class TagGenerator
  constructor: (@path) ->

  parseTagLine: (line) ->
    sections = line.split('\t')
    if sections.length > 3
      position: new Point(parseInt(sections[2]) - 1)
      name: sections[0]
    else
      null

  generate: ->
    deferred = $.Deferred()
    tags = []
    command = "#{require.resolve('ctags')}"
    args = ['--fields=+KS', '-nf', '-', @path]
    stdout = (lines) =>
      for line in lines.split('\n')
        tag = @parseTagLine(line)
        tags.push(tag) if tag
    exit = ->
      deferred.resolve(tags)
    new BufferedProcess({command, args, stdout, exit})
    deferred
