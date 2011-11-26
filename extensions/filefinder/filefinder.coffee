_ = require 'underscore'
fs = require 'fs'

Extension = require 'extension'
ModalSelector = require 'modal-selector'

module.exports =
class Filefinder extends Extension
  settings:
    cache: false

  cached: null

  constructor: ->
    atom.on 'project:open', @startup

  startup: (@project) =>
    @pane = new ModalSelector @findURLs

  findURLs: =>
    return @cached if @settings.cache and @cached

    # always set cached, whether if we care about it or not.
    @cached = _.reject @project.allURLs(), ({url}) ->
      fs.isDirectory url

  toggle: ->
    @pane?.toggle()
