Point = require 'point'
ChildProcess = nodeRequire 'child_process'
$ = require 'jquery'

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
    command = "#{require.resolve('ctags')}"
    args = ["--fields=+KS", "-nf", "-", "#{@path}"]
    ctags = ChildProcess.spawn(command, args)
    deferred = $.Deferred()
    output = ''
    ctags.stdout.setEncoding('utf8')
    ctags.stdout.on 'data', (data) ->
      output += data
    ctags.stdout.on 'close', =>
      tags = []
      for line in output.split('\n')
        tag = @parseTagLine(line)
        tags.push(tag) if tag
      deferred.resolve(tags)
    deferred
