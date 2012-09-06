(function() {
  native function buildOnigRegExp(source);
  native function search(string, index);
  native function getCaptureIndices(string, index);
  native function captureIndices(string, index, regexes);
  native function getCaptureCount();
  native function test(string);

  function OnigRegExp(source) {
    var regexp = buildOnigRegExp(source);
    regexp.constructor = OnigRegExp;
    regexp.__proto__ = OnigRegExp.prototype;
    regexp.source = source;
    return regexp;
  }

  OnigRegExp.prototype.search = search;
  OnigRegExp.prototype.test = test;
  OnigRegExp.prototype.getCaptureIndices = getCaptureIndices;
  OnigRegExp.prototype.getCaptureCount = getCaptureCount;
  OnigRegExp.captureIndices = captureIndices;

  this.OnigRegExp = OnigRegExp;
})();

