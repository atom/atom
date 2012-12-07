var setGlobalFocusPriority = function(priority) {
  env = jasmine.getEnv();
  if (!env.focusPriority) env.focusPriority = 1;
  if (priority > env.focusPriority) env.focusPriority = priority;
};

exports.fdescribe = function(description, specDefinitions, priority) {
  if (!priority) priority = 1;
  setGlobalFocusPriority(priority)
  var suite = describe(description, specDefinitions);
  suite.focusPriority = priority;
  return suite;
};

exports.ffdescribe = function(description, specDefinitions) {
  fdescribe(description, specDefinitions, 2);
};

exports.fffdescribe = function(description, specDefinitions) {
  fdescribe(description, specDefinitions, 3);
};

exports.fit = function(description, definition, priority) {
  if (!priority) priority = 1;
  setGlobalFocusPriority(priority);
  var spec = it(description, definition);
  spec.focusPriority = priority;
  return spec;
};

exports.ffit = function(description, specDefinitions) {
  fit(description, specDefinitions, 2);
};

exports.fffit = function(description, specDefinitions) {
  fit(description, specDefinitions, 3);
};

var fSpecFilter = function(specOrSuite) {
  globalFocusPriority = jasmine.getEnv().focusPriority;
  if (!globalFocusPriority) return true;
  if (specOrSuite.focusPriority >= globalFocusPriority) return true;

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

  if (!paramMap.spec && !jasmine.getEnv().focusPriority) {
    return true;
  }

  return (spec.getFullName().indexOf(paramMap.spec) === 0) || fSpecFilter(spec);
};
