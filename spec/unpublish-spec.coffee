express = require 'express'
http = require 'http'
temp = require 'temp'
apm = require '../lib/apm-cli'

describe 'apm unpublish', ->
  [server, unpublishPackageCallback, unpublishVersionCallback] = []

  beforeEach ->
    silenceOutput()
    spyOnToken()

    unpublishPackageCallback = jasmine.createSpy('unpublishPackageCallback')
    unpublishVersionCallback = jasmine.createSpy('unpublishVersionCallback')

    app = express()

    app.delete '/packages/test-package', (request, response) ->
      unpublishPackageCallback()
      response.status(204).send(204)

    app.delete '/packages/test-package/versions/1.0.0', (request, response) ->
      unpublishVersionCallback()
      response.status(204).send(204)

    server =  http.createServer(app)
    server.listen(3000)

    process.env.ATOM_HOME = temp.mkdirSync('apm-home-dir-')
    process.env.ATOM_API_URL = "http://localhost:3000"

  afterEach ->
    server.close()

  describe "when no version is specified", ->
    it 'unpublishes the package', ->
      callback = jasmine.createSpy('callback')
      apm.run(['unpublish', '--force', 'test-package'], callback)

      waitsFor 'waiting for unpublish command to complete', ->
        callback.callCount > 0

      runs ->
        expect(callback.argsForCall[0][0]).toBeUndefined()
        expect(unpublishPackageCallback.callCount).toBe 1
        expect(unpublishVersionCallback.callCount).toBe 0

    describe "when the package does not exist", ->
      it "calls back with an error", ->
        callback = jasmine.createSpy('callback')
        apm.run(['unpublish', '--force', 'not-a-package'], callback)

        waitsFor 'waiting for unpublish command to complete', ->
          callback.callCount > 0

        runs ->
          expect(callback.argsForCall[0][0]).not.toBeUndefined()
          expect(unpublishPackageCallback.callCount).toBe 0
          expect(unpublishVersionCallback.callCount).toBe 0

  describe "when a version is specified", ->
    it 'unpublishes the version', ->
      callback = jasmine.createSpy('callback')
      apm.run(['unpublish', '--force', 'test-package@1.0.0'], callback)

      waitsFor 'waiting for unpublish command to complete', ->
        callback.callCount > 0

      runs ->
        expect(callback.argsForCall[0][0]).toBeUndefined()
        expect(unpublishPackageCallback.callCount).toBe 0
        expect(unpublishVersionCallback.callCount).toBe 1

    describe "when the version does not exist", ->
      it "calls back with an error", ->
        callback = jasmine.createSpy('callback')
        apm.run(['unpublish', '--force', 'test-package@2.0.0'], callback)

        waitsFor 'waiting for unpublish command to complete', ->
          callback.callCount > 0

        runs ->
          expect(callback.argsForCall[0][0]).not.toBeUndefined()
          expect(unpublishPackageCallback.callCount).toBe 0
          expect(unpublishVersionCallback.callCount).toBe 0
