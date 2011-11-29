
Extension = require 'extension'

module.exports =
class OpenedURLs extends Extension
  storageKey: "#{$atomController.url}.openedFiles"
  openedURLs: null

  constructor: ->
    atom.on 'window:load', @startup
    atom.on 'project:resource:open', @add
    atom.on 'project:resource:close', @remove

  startup: =>
    super
    @openedURLs = atom.storage.get @storageKey, []
    window.open url for url in @openedURLs

  add: (project, resource) =>
    @openedURLs.push resource.url unless resource.url in @openedURLs

  remove: (project, resource) =>
    if (i = @openedURLs.indexOf resource.url) > -1
      @openedURLs.splice i, 1

  shutdown: ->
    super
    atom.storage.set @storageKey, @openedURLs
