'use strict'

class FakeRemoteDirectory {
  constructor (uri) {
    this.uri = uri
  }

  relativize (uri) {
    return uri
  }

  getPath () {
    return this.uri
  }

  isRoot () {
    return true
  }

  getSubdirectory () {
    return {
      existsSync () {
        return false
      }
    }
  }

  existsSync () {
    return true
  }

  contains () {
    return false
  }
}

exports.provideDirectoryProvider = function () {
  return {
    name: 'directory provider from package-with-directory-provider',

    directoryForURISync (uri) {
      if (uri.startsWith('remote://')) {
        return new FakeRemoteDirectory(uri)
      }
    }
  }
}
