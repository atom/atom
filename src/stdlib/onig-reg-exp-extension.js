(function() {
  native function buildOnigRegExp(source);
  native function search(string, index);

  function OnigRegExp(source) {
    var regexp = buildOnigRegExp(source);
    regexp.constructor = OnigRegExp;
    regexp.__proto__ = OnigRegExp.prototype;
    return regexp;
  }

  OnigRegExp.prototype.search = search;

  this.OnigRegExp = OnigRegExp;
})();

