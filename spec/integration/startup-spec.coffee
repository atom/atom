# These tests are excluded by default. To run them from the command line:
#
# ATOM_INTEGRATION_TESTS_ENABLED=true apm test
return unless process.env.ATOM_INTEGRATION_TESTS_ENABLED
# Integration tests require a fast machine and, for now, we cannot afford to
# run them on Travis.
return if process.env.CI

fs = require 'fs-plus'
path = require 'path'
temp = require('temp').track()
runAtom = require './helpers/start-atom'
CSON = require 'season'

describe "Starting Atom", ->
  atomHome = temp.mkdirSync('atom-home')
  [tempDirPath, otherTempDirPath] = []

  beforeEach ->
    jasmine.useRealClock()
    fs.writeFileSync(path.join(atomHome, 'config.cson'), fs.readFileSync(path.join(__dirname, 'fixtures', 'atom-home', 'config.cson')))
    fs.removeSync(path.join(atomHome, 'storage'))

    tempDirPath = temp.mkdirSync("empty-dir")
    otherTempDirPath = temp.mkdirSync("another-temp-dir")
