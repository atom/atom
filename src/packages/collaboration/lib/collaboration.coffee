Peer = require './peer'

createConnection = ->
  peer = new Peer('some-id1', {host: 'ec2-54-218-51-127.us-west-2.compute.amazonaws.com', port: 8080})
  peer.on 'connection', (connection) ->
    console.log 'connection'
    connection.on 'data', (data) ->
      console.log('Got data:', data)

module.exports =
  activate: ->
    createConnection()
    peer = new Peer('some-id2', {host: 'ec2-54-218-51-127.us-west-2.compute.amazonaws.com', port: 8080})
    c2 = peer.connect('some-id1')
    c2.on 'open', -> c2.send('test?')
