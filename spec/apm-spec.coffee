path = require 'path'
http = require 'http'
express = require 'express'
apm = require '../lib/apm'
auth = require '../lib/auth'

describe 'apm API', ->
  describe '.getAvailablePackages(atomVersion, callback)', ->
    server = null

    beforeEach ->
      spyOn(auth, 'getToken').andCallFake (callback) -> callback(null, 'token')
      app = express()
      app.get '/available', (request, response) ->
        response.sendfile path.join(__dirname, 'fixtures', 'available.json')
      server =  http.createServer(app)
      server.listen(3000)

      process.env.ATOM_PACKAGES_URL = 'http://localhost:3000/available'

    afterEach ->
      server.close()

    describe 'when no version is specified', ->
      it 'returns the highest version of each package', ->
        available = null

        apm.getAvailablePackages (error, packages) -> available = packages

        waitsFor -> available?

        runs ->
          expect(available.length).toBe 2
          expect(available[0].name).toBe 'beverly-hills'
          expect(available[1].name).toBe 'multi-version'
          expect(available[1].version).toBe '2.0.0'

    xdescribe 'when a version is specified', ->
      it 'returns the packages that are applicable for that version', ->
        available = null

        apm.getAvailablePackages '1.0.0', (error, packages) ->
          available = packages

        waitsFor -> available?

        runs ->
          expect(available.length).toBe 2
          expect(available[0].name).toBe 'beverly-hills'
          expect(available[1].name).toBe 'multi-version'
          expect(available[1].version).toBe '1.0.0'
