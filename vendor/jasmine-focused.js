var setGlobalFocusPriority = function(priority) {
  env = jasmine.getEnv();
  if (!env.focusPriority) env.focusPriority = 1;
  if (priority > env.focusPriority) env.focusPriority = priority;
};

var fdescribe = function(description, specDefinitions, priority) {
  if (!priority) priority = 1;
  setGlobalFocusPriority(priority)
  var suite = describe(description, specDefinitions);
  suite.focusPriority = priority;
  return suite;
};

var ffdescribe = function(description, specDefinitions) {
  fdescribe(description, specDefinitions, 2);
};

var fffdescribe = function(description, specDefinitions) {
  fdescribe(description, specDefinitions, 3);
};

var fit = function(description, definition, priority) {
  if (!priority) priority = 1;
  setGlobalFocusPriority(priority);
  var spec = it(description, definition);
  spec.focusPriority = priority;
  return spec;
};

var ffit = function(description, specDefinitions) {
  fit(description, specDefinitions, 2);
};

var fffit = function(description, specDefinitions) {
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
  console.log(window.location)

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

