{create6to5VersionAndOptionsDigest} = require '../src/esnext'
crypto = require 'crypto'

describe "::create6to5VersionAndOptionsDigest", ->

  it "returns a digest for the library version and specified options", ->
    defaultOptions =
      'blacklist': [
        'useStrict'
      ]
      'experimental': true
      'optional': [
        'asyncToGenerator'
      ]
      'reactCompat': true
      'sourceMap': 'inline'
    version = '3.0.14'
    shasum = crypto.createHash('sha1')
    shasum.update('6to5-core', 'utf8')
    shasum.update('\0', 'utf8')
    shasum.update(version, 'utf8')
    shasum.update('\0', 'utf8')
    shasum.update('{"blacklist": ["useStrict",],"experimental": true,"optional": ["asyncToGenerator",],"reactCompat": true,"sourceMap": "inline",}')
    expectedDigest = shasum.digest('hex')

    observedDigest = create6to5VersionAndOptionsDigest(version, defaultOptions)
    expect(observedDigest).toEqual(expectedDigest)
