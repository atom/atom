(function() {
  native function buildOnigRegexp(source);
  native function exec(string);

  function OnigRegexp(source) {
    var regexp = buildOnigRegexp(source);
    regexp.constructor = OnigRegexp;
    regexp.__proto__ = OnigRegexp.prototype;
    return regexp;
  }

  OnigRegexp.prototype.exec = exec;

  this.OnigRegexp = OnigRegexp;
})();

