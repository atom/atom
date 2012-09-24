(function() {
  native function buildOnigRegExp(source);
  native function search(string, index);
  native function test(string);
  native function captureIndices(string, index, regexes);

  function OnigRegExp(source) {
    var regexp = buildOnigRegExp(source);
    regexp.constructor = OnigRegExp;
    regexp.__proto__ = OnigRegExp.prototype;
    regexp.source = source;
    return regexp;
  }

  OnigRegExp.prototype.search = search;
  OnigRegExp.prototype.test = test;
  OnigRegExp.captureIndices = captureIndices;

  this.OnigRegExp = OnigRegExp;
})();

