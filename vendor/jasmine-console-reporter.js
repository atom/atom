jasmine.ConsoleReporter = function(doc, logErrors) {
  this.logErrors = logErrors == false ? false : true
};

jasmine.ConsoleReporter.prototype.reportRunnerStarting = function(runner) {
  var showPassed, showSkipped;
  var suites = runner.suites();
  this.startedAt = new Date();
};

jasmine.ConsoleReporter.prototype.reportRunnerResults = function(runner) {
  var results = runner.results();
  var specs = runner.specs();
  var specCount = specs.legnth;
  var message = "" + specCount + " spec" + (specCount == 1 ? "" : "s" ) + ", " + results.failedCount + " failure" + ((results.failedCount == 1) ? "" : "s");
  message += " in " + ((new Date().getTime() - this.startedAt.getTime()) / 1000) + "s";

  $native.exit(results.failedCount > 0 ? 1 : 0)
};

jasmine.ConsoleReporter.prototype.reportSuiteResults = function(suite) {
};

jasmine.ConsoleReporter.prototype.reportSpecResults = function(spec) {
  var results = spec.results();
  var status = results.passed() ? 'passed' : 'failed';
  if (results.skipped) {
    status = 'skipped';
  }
  var resultItems = results.getItems();
  for (var i = 0; i < resultItems.length; i++) {
    var result = resultItems[i];
    if (this.logErrors && result.type == 'expect' && result.passed && !result.passed()) {
      console.log("ERROR: " + spec.getFullName())
      if (result.trace.stack) {
        console.log(result.trace.stack)
      }
      else {
       console.log(result.message)
      }
    }
  }
};

jasmine.ConsoleReporter.prototype.specFilter = function(spec) {
  return true;
};
