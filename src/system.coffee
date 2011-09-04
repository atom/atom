# commonjs system module
# http://ringojs.org/api/v0.8/system/

module.exports =
  # An object containing our environment variables.
  env: ->
    OSX.NSProcess.processInfo.environment
