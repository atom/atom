module.exports =
class Project
  @scan: (path, selectCallback, sortCallback) ->
    fs = OSX.NSFileManager.defaultManager
    dirEnumerator = fs.enumeratorAtPath rootPath

    results = []
    while path = dirEnumerator.nextObject
      path = path.valueOf()
      if not selectCallback or selectCallback(path)
        results.push path
        results.sort sortCallback if sortCallback

    results

