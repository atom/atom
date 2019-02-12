require('jasmine-reporters')

class JasmineJUnitReporter extends jasmine.JUnitXmlReporter {
  fullDescription (spec) {
    let fullDescription = spec.description
    let currentSuite = spec.suite
    while (currentSuite) {
      fullDescription = currentSuite.description + ' ' + fullDescription
      currentSuite = currentSuite.parentSuite
    }

    if (process.env.TEST_JUNIT_RUN) {
      fullDescription = `[${process.env.TEST_JUNIT_RUN}] ` + fullDescription
    }

    return fullDescription
  }

  reportSpecResults (spec) {
    spec.description = this.fullDescription(spec)
    return super.reportSpecResults(spec)
  }
}

module.exports = { JasmineJUnitReporter }
