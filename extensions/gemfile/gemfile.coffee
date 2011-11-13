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
    gemfile = _.detect urls, (url) -> /Gemfile/i.test url

    if gemfile
      console.log
        label: "RubyGems"
        url: "http://rubygems.org/"
        urls: @gemsFromGemFile gemfile

  gemsFromGemFile: (url) ->
    file = fs.read url
    gems = []

    for line in file.split "\n"
      if gem = line.match(/^\s*gem ['"](.+?)['"]/)?[1]
        gems.push label: gem, url: "https://rubygems.org/gems/#{gem}"

    gems