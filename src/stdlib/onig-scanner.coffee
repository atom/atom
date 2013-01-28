module.exports =
class OnigScanner
  constructor: (sources) ->
    scanner = $onigScanner.buildScanner(sources)
    scanner.constructor = OnigScanner
    scanner.__proto__ = OnigScanner.prototype
    scanner.sources = sources
    return scanner

  findNextMatch: $onigScanner.findNextMatch
