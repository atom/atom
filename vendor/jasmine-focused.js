var fdescribe = function(description, specDefinitions) {
  jasmine.getEnv().focus = true
  var suite = describe(description, specDefinitions);
  suite.focus = true;
  return suite;
};

var fit = function(description, definition) {
  jasmine.getEnv().focus = true
  var spec = it(description, definition);
  spec.focus = true;
  return spec;
};

var fSpecFilter = function(specOrSuite) {
  if (!jasmine.getEnv().focus) return true;
  if (specOrSuite.focus) return true;

  var parent = specOrSuite.parentSuite || specOrSuite.suite;
  if (!parent) return false;
  return fSpecFilter(parent);
}

jasmine.AtomReporter.prototype.specFilter = function(spec) {
  var paramMap = {};
  var params = this.getLocation().search.substring(1).split('&');
  for (var i = 0; i < params.length; i++) {
    var p = params[i].split('=');
    paramMap[decodeURIComponent(p[0])] = decodeURIComponent(p[1]);
  }

  if (!paramMap.spec && !jasmine.getEnv().focus) {
    return true;
  }

  return (spec.getFullName().indexOf(paramMap.spec) === 0) || fSpecFilter(spec);
};

