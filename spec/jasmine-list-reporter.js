const { TerminalReporter } = require('jasmine-tagged');

class JasmineListReporter extends TerminalReporter {
  fullDescription(spec) {
    let fullDescription = 'it ' + spec.description;
    let currentSuite = spec.suite;
    while (currentSuite) {
      fullDescription = currentSuite.description + ' > ' + fullDescription;
      currentSuite = currentSuite.parentSuite;
    }
    return fullDescription;
  }

  reportSpecStarting(spec) {
    this.print_(this.fullDescription(spec) + ' ');
  }

  reportSpecResults(spec) {
    const result = spec.results();
    if (result.skipped) {
      return;
    }

    let msg = '';
    if (result.passed()) {
      msg = this.stringWithColor_('[pass]', this.color_.pass());
    } else {
      msg = this.stringWithColor_('[FAIL]', this.color_.fail());
      this.addFailureToFailures_(spec);
    }
    this.printLine_(msg);
  }
}

module.exports = { JasmineListReporter };
