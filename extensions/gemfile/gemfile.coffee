$ = require 'jquery'
_ = require 'underscore'

fs = require 'fs'
Extension = require 'extension'
KeyBinder = require 'key-binder'
Watcher = require 'watcher'

module.exports =
class Gemfile extends Extension
  constructor: ->
    atom.on 'project:open', @startup

  startup: (@project) =>
    urls = @project.urls()
    {url} = _.detect urls, ({url}) -> /Gemfile/i.test url

    if url
      @project.settings.extraURLs[@project.url] = [
        name: "RubyGems"
        url: "http://rubygems.org/"
        type: 'dir'
      ]
      @project.settings.extraURLs["http://rubygems.org/"] = @gems url

  gems: (url) ->
    file = fs.read url
    gems = []

    for line in file.split "\n"
      if gem = line.match(/^\s*gem ['"](.+?)['"]/)?[1]
        gems.push type: 'file', name: gem, url: "https://rubygems.org/gems/#{gem}"

    gems