module.exports =
class OnigScanner
  @create: (sources) ->
    scanner = $onigScanner.buildScanner(sources)
    scanner.constructor = OnigScanner
    scanner.__proto__ = OnigScanner.prototype
    scanner.sources = sources
    scanner

  findNextMatch: $onigScanner.findNextMatch
