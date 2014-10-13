_ = require 'underscore-plus'
{EventEmitter} = require 'events'

module.exports =
class AutoUpdater
  _.extend @prototype, EventEmitter.prototype

  setFeedUrl: ->
    console.log 'setFeedUrl'

  quitAndInstall: ->
    console.log 'quitAndInstall'

  checkForUpdates: ->
    console.log 'checkForUpdates'
