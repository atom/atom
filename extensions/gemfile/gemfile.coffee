$ = require 'jquery'
_ = require 'underscore'

fs = require 'fs'
Extension = require 'extension'
KeyBinder = require 'key-binder'
Watcher = require 'watcher'

module.exports =
class Gemfile extends Extension
  constructor: ->
    atom.event.on 'extensions:loaded', @addRubyGemsDir

  addRubyGemsDir: =>
    paths = window.extensions.Tree.paths
    gemfile = _.detect paths, ({path}) -> /Gemfile/i.test path

    if gemfile
      paths.push
        label: "RubyGems"
        path: "http://rubygems.org/"
        paths: @gemsFromGemFile gemfile.path
      window.extensions.Tree.reload()

  gemsFromGemFile: (path) ->
    file = fs.read path
    gems = []

    for line in file.split "\n"
      if gem = line.match(/^\s*gem ['"](.+?)['"]/)?[1]
        gems.push label: gem, path: "https://rubygems.org/gems/#{gem}"

    gems