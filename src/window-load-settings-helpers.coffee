windowLoadSettings = null

exports.getWindowLoadSettings = ->
  windowLoadSettings ?= JSON.parse(window.decodeURIComponent(window.location.hash.substr(1)))

exports.setWindowLoadSettings = (settings) ->
  windowLoadSettings = settings
  location.hash = encodeURIComponent(JSON.stringify(settings))
