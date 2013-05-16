module.exports =
  getAvailablePackages: (callback) ->
    Fetcher = require('./fetcher')
    new Fetcher().getAvailablePackages(callback)
