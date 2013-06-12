module.exports = ->
  try
    require 'jquery'
    true
  catch e
    false
