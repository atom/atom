path = require 'path'
CSON = require 'season'
fs = require 'fs-plus'
temp = require 'temp'
express = require 'express'
http = require 'http'
wrench = require 'wrench'
apm = require '../lib/apm-cli'

describe 'apm rebuild', ->
  [server, originalPathEnv] = []

  beforeEach ->
    spyOnToken()
    silenceOutput()

    app = express()
    app.get '/node/v0.10.3/node-v0.10.3.tar.gz', (request, response) ->
      response.sendfile path.join(__dirname, 'fixtures', 'node-v0.10.3.tar.gz')
    app.get '/node/v0.10.3/node.lib', (request, response) ->
      response.sendfile path.join(__dirname, 'fixtures', 'node.lib')
    app.get '/node/v0.10.3/x64/node.lib', (request, response) ->
      response.sendfile path.join(__dirname, 'fixtures', 'node_x64.lib')
    app.get '/node/v0.10.3/SHASUMS256.txt', (request, response) ->
      response.sendfile path.join(__dirname, 'fixtures', 'SHASUMS256.txt')

    server =  http.createServer(app)
    server.listen(3000)

    atomHome = temp.mkdirSync('apm-home-dir-')
    process.env.ATOM_HOME = atomHome
    process.env.ATOM_ELECTRON_URL = "http://localhost:3000/node"
    process.env.ATOM_PACKAGES_URL = "http://localhost:3000/packages"
    process.env.ATOM_ELECTRON_VERSION = 'v0.10.3'
    process.env.ATOM_RESOURCE_PATH = temp.mkdirSync('atom-resource-path-')

    originalPathEnv = process.env.PATH
    process.env.PATH = ""

  afterEach ->
    server.close()
    process.env.PATH = originalPathEnv

  it "rebuilds all modules when no module names are specified", ->
    packageToRebuild = path.join(__dirname, 'fixtures/package-with-native-deps')

    process.chdir(packageToRebuild)
    callback = jasmine.createSpy('callback')
    apm.run(['rebuild'], callback)

    waitsFor 'waiting for rebuild to complete', 600000, ->
      callback.callCount is 1

    runs ->
      expect(callback.mostRecentCall.args[0]).toBeUndefined()

  it "rebuilds the specified modules", ->
    packageToRebuild = path.join(__dirname, 'fixtures/package-with-native-deps')

    process.chdir(packageToRebuild)
    callback = jasmine.createSpy('callback')
    apm.run(['rebuild', 'native-dep'], callback)

    waitsFor 'waiting for rebuild to complete', 600000, ->
      callback.callCount is 1

    runs ->
      expect(callback.mostRecentCall.args[0]).toBeUndefined()
