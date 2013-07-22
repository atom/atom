var _ = require('underscore');
var convertStackTrace = require('coffeestack').convertStackTrace;

var sourceMaps = {};
var formatStackTrace = function(stackTrace) {
  if (!stackTrace)
    return stackTrace;

  // Remove all lines containing jasmine.js path
  var jasminePath = require.resolve('jasmine');
  var jasminePattern = new RegExp("\\(" + _.escapeRegExp(jasminePath) + ":\\d+:\\d+\\)\\s*$");
  var convertedLines = [];
  var lines = stackTrace.split('\n');
  for (var i = 0; i < lines.length; i++)
    if (!jasminePattern.test(lines[i]))
      convertedLines.push(lines[i]);

  //Remove last util.spawn.callDone line and all lines after it
  var gruntSpawnPattern = /^\s*at util\.spawn\.callDone\s*\(.*\/grunt\/util\.js:\d+:\d+\)\s*$/
  for (var i = convertedLines.length - 1; i > 0; i--)
    if (gruntSpawnPattern.test(convertedLines[i])) {
      convertedLines = convertedLines.slice(0, i);
      break;
    }

  return convertStackTrace(convertedLines.join('\n'), sourceMaps);
}

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

  atom.exit(results.failedCount > 0 ? 1 : 0)
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
      message = spec.getFullName()
      console.log("\n\n" + message)
      console.log((new Array(message.length + 1)).join('-'))
      if (result.trace.stack) {
        console.log(formatStackTrace(result.trace.stack));
      }
      else {
       console.log(result.message)
      }
    }
  }
};

jasmine.ConsoleReporter.prototype.specFilter = function(spec) {
  var globalFocusPriority = jasmine.getEnv().focusPriority
  var parent = spec.parentSuite || spec.suite

  if (!globalFocusPriority) {
    return true
  }
  else if (spec.focusPriority >= globalFocusPriority) {
    return true
  }
  else if (!parent) {
    return false
  }
  else {
    return this.specFilter(parent)
  }
};
