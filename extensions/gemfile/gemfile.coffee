$ = require 'jquery'
_ = require 'underscore'

fs = require 'fs'
Extension = require 'extension'
ModalSelector = require 'modal-selector'

module.exports =
class Gemfile extends Extension
  constructor: ->
    atom.keybinder.load require.resolve "gemfile/key-bindings.coffee"
    atom.on 'project:open', @startup

  startup: (@project) =>
    urls = @project.urls()
    gemfile = _.detect urls, ({url}) -> /Gemfile/i.test url
    {url} = gemfile if gemfile

    if url
      @project.settings.extraURLs[@project.url] = [
        name: "RubyGems"
        url: "http://rubygems.org/"
        type: 'dir'
      ]
      gems = @gems url
      @project.settings.extraURLs["http://rubygems.org/"] = gems
      @pane = new ModalSelector gems

  toggle: ->
    @pane?.toggle()

  gems: (url) ->
    file = fs.read url
    gems = []

    for line in file.split "\n"
      if gem = line.match(/^\s*gem ['"](.+?)['"]/)?[1]
        gems.push type: 'file', name: gem, url: "https://rubygems.org/gems/#{gem}"

    gems