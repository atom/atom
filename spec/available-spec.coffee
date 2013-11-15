path = require 'path'
express = require 'express'
http = require 'http'
apm = require '../lib/apm-cli'

describe 'apm available', ->
  server = null

  beforeEach ->
    silenceOutput()
    spyOnToken()

    app = express()
    app.get '/available', (request, response) ->
      response.sendfile path.join(__dirname, 'fixtures', 'available.json')
    server =  http.createServer(app)
    server.listen(3000)

    process.env.ATOM_PACKAGES_URL = "http://localhost:3000/available"

  afterEach ->
    server.close()

  it 'lists the available packages', ->
    callback = jasmine.createSpy('callback')
    apm.run(['available'], callback)

    waitsFor 'waiting for command to complete', ->
      callback.callCount > 0

    runs ->
      expect(console.log).toHaveBeenCalled()
      expect(console.log.argsForCall[1][0]).toContain 'beverly-hills@9.0.2.1.0'

  describe 'when the theme flag is specified', ->
    it "only lists themes", ->
      callback = jasmine.createSpy('callback')
      apm.run(['available', '--themes'], callback)

      waitsFor 'waiting for command to complete', ->
        callback.callCount > 0

      runs ->
        expect(console.log).toHaveBeenCalled()
        expect(console.log.argsForCall[1][0]).toContain 'blossom@19.92'
        expect(console.log.argsForCall[1][0]).not.toContain 'beverly-hills@9.0.2.1.0'
