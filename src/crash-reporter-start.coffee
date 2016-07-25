module.exports = (extra) ->
  {crashReporter} = require 'electron'

  crashReporter.start({
    productName: 'Atom',
    companyName: 'GitHub',
    autoSubmit: false,
    extra: extra
  })
