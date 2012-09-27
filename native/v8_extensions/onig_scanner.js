(function() {
  native function buildScanner(sources);
  native function findNextMatch(string, startPosition);

  function OnigScanner(sources) {
    var scanner = buildScanner(sources);
    scanner.constructor = OnigScanner;
    scanner.__proto__ = OnigScanner.prototype;
    scanner.sources = sources;
    return scanner;
  }

  OnigScanner.prototype.buildScanner = buildScanner;
  OnigScanner.prototype.findNextMatch = findNextMatch;

  this.OnigScanner = OnigScanner;
})();
