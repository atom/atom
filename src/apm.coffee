module.exports =
  getAvailablePackages: (atomVersion, callback) ->
    Fetcher = require('./fetcher')
    new Fetcher().getAvailablePackages(atomVersion, callback)
