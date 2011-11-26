_ = require 'underscore'
$ = require 'jquery'
fs = require 'fs'
handlebars = require 'handlebars'

ChildProcess = require 'child-process'
Browser = require 'browser'
Extension = require 'extension'
ModalSelector = require 'modal-selector'

module.exports =
class FindInProject extends Browser
  window.resourceTypes.push this

  running: true

  # Array of { name, url } objects
  results: []

  # String search term
  term: ''

  open: (url) ->
    return if not url

    if match = url.match /^findinproject:\/\/(.+)/
      @term = match[1]
      @url = url
      @title = "Find #{@term}"
      @findInProject @term, (@results) => @show()
      true

  findInProject: (term, callback) ->
    return callback [] if not url = window.url

    ChildProcess.exec "ack --ignore-dir=Cocoa/build --ignore-dir=vendor #{term} #{url}", (error, stdout, stderr) ->
      callback _.compact _.map (stdout.split "\n"), (line) ->
        return if _.isEmpty line.trim()
        name: line.replace "#{url}/", ''
        url: _.first line.split ":"

  add: ->
    super @render()

    # gross!
    iframe = $ $('iframe')[0].contentDocument.body

    iframe.find('#find-in-project-results-view a').click ->
      window.open this.href.replace 'file://', ''
      false

  render: ->
    results = _.map @results, ({name, url}) =>
      line = _.escape name
      [file, match...] = line.split ':'

      match: (match.join ':').replace(@term, "<code>#{@term}</code>")
      url: url
      file: file

    @template results: results

  template: handlebars.compile '''
    <link rel="stylesheet" href="static/bootstrap-1.4.0.css">
    <style>body { padding:10px; }</style>
    <h1>Results</h1>
    <ul id="find-in-project-results-view">
    {{#each results}}
      <li><a href='{{url}}'>{{{file}}}:{{{match}}}</a></li>
    {{/each}}
    </ul>
  '''
