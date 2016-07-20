module.exports = (extra) ->
  {crashReporter} = require 'electron'

  crashReporter.start({
    productName: 'Atom',
    companyName: 'GitHub',
    submitURL: 'http://localhost:1127/post'
    extra: extra
  })
