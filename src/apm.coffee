module.exports =
  getAvailablePackages: (atomVersion, callback) ->
    Available = require('./available')
    new Available().getAvailablePackages(atomVersion, callback)
