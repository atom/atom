module.exports = (extra) ->
  {crashReporter} = require 'electron'

  crashReporter.start({
    productName: 'Atom',
    companyName: 'GitHub',
    submitURL: 'http://54.249.141.255:1127/post'
    extra: extra
  })
