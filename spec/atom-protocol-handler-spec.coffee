{$} = require '../src/space-pen-extensions'

fetch = (url, callback) ->
  $.ajax
    url: url
    success: callback
    # In old versions of jQuery, ajax calls to custom protocol would always
    # be treated as error eventhough the browser thinks it's a success
    # request.
    error: callback
  

describe '"atom" protocol URL', ->
  it 'sends the file relative in the package as response', ->
    called = 0
    callback = -> called += 1
    fetch('atom://async/package.json', callback)
    fetch('atom://async/package.json#some-hash', callback)
    fetch('atom://async/package.json?some&params=value', callback)
    fetch('atom://async/package.json?', callback) # test edge-case
    fetch('atom://async/package.json#', callback) # test edge-case

    waitsFor 'request to be done', -> called is 5
