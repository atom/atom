path = require 'path'
express = require 'express'
http = require 'http'
apm = require '../lib/apm-cli'

describe 'apm view', ->
  server = null

  beforeEach ->
    silenceOutput()
    spyOnToken()

    app = express()
    app.get '/wrap-guide', (request, response) ->
      response.sendfile path.join(__dirname, 'fixtures', 'wrap-guide.json')
    server =  http.createServer(app)
    server.listen(3000)

    process.env.ATOM_PACKAGES_URL = "http://localhost:3000"

  afterEach ->
    server.close()

  it 'displays information about the package', ->
    callback = jasmine.createSpy('callback')
    apm.run(['view', 'wrap-guide'], callback)

    waitsFor 'waiting for view to complete', ->
      callback.callCount > 0

    runs ->
      expect(console.log).toHaveBeenCalled()
      expect(console.log.argsForCall[0][0]).toContain 'wrap-guide'
      expect(console.log.argsForCall[1][0]).toContain '0.14.0'
      expect(console.log.argsForCall[2][0]).toContain 'https://github.com/atom/wrap-guide'
      expect(console.log.argsForCall[3][0]).toContain 'new version'

  it "logs an error if the package name is missing or empty", ->
    callback = jasmine.createSpy('callback')
    apm.run(['view'], callback)

    waitsFor 'waiting for view to complete', ->
      callback.callCount > 0

    runs ->
      expect(console.error).toHaveBeenCalled()
      expect(console.error.argsForCall[0][0].length).toBeGreaterThan 0

  describe "when a compatible Atom version is specified", ->
    it "displays the latest compatible version of the package", ->
      callback = jasmine.createSpy('callback')
      apm.run(['view', 'wrap-guide', '--compatible', '1.5.0'], callback)

      waitsFor 'waiting for view to complete', 600000, ->
        callback.callCount is 1

      runs ->
        expect(console.log.argsForCall[0][0]).toContain 'wrap-guide'
        expect(console.log.argsForCall[1][0]).toContain '0.3.0'
        expect(console.log.argsForCall[2][0]).toContain 'https://github.com/atom2/wrap-guide'
        expect(console.log.argsForCall[3][0]).toContain 'old version'
