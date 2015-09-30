'use babel'
/* @flow */

import fs from 'fs'

/**
 * This interface is defined by https://github.com/jasmine/jasmine/blob/1_3_x/src/core/Env.js.
 */
type JasmineEnv = {
  constructor(): void,
  addReporter(reporter: JasmineReporter): void,
  execute(): void,

  /**
   * This method is not a standard part of Jasmine 1.3.1. It is included via
   * https://github.com/atom/jasmine-tagged/blob/master/src/jasmine-tagged.coffee.
   */
  setIncludedTags(tags: string[]): string[],
}

/**
 * This interface is defined by https://github.com/jasmine/jasmine/blob/1_3_x/src/core/base.js.
 */
type JasmineExpectationResult = {
  constructor(params: {
    matcherName: string,
    passed: boolean,
    expected: mixed,
    actual: mixed,
    message: string,
    trace?: ?Error,
  }): void,
  type: 'expect',
  toString(): string,
  passed(): boolean,
}

/**
 * This interface is defined by https://github.com/jasmine/jasmine/blob/1_3_x/src/core/base.js.
 */
type JasmineMessageResult = {
  constructor(values: mixed[]): void,
  type: 'log',
  toString(): string,
}

/**
 * This interface is defined by https://github.com/jasmine/jasmine/blob/1_3_x/src/core/NestedResults.js.
 */
type JasmineNestedResults = {
  totalCount: number,
  passedCount: number,
  failedCount: number,
  skipped: boolean,
  rollupCounts(result: JasmineNestedResults): void,
  log(values: mixed[]): void,
  getItems(): Array<JasmineExpectationResult | JasmineNestedResults | JasmineMessageResult>,

  /**
   * - If result is a JasmineNestedResults, it will be passed to rollupCounts().
   * - If result is a JasmineExpectationResult, it will update this JasmineNestedResults's internal
   *   counts.
   * - If result is a JasmineMessageResult, it just gets added to the list of things returned by
   *   getItems().
   */
  addResult(result: JasmineExpectationResult | JasmineNestedResults | JasmineMessageResult): void,
  passed(): boolean,
}

/**
 * This interface is defined by https://github.com/jasmine/jasmine/blob/1_3_x/src/core/Runner.js.
 */
type JasmineRunner = {
  constructor(env: JasmineEnv): void,
  results(): JasmineNestedResults,
  specs(): JasmineSpec[],
  topLevelSuites(): JasmineSuite[],

  // Admittedly, this has many more methods, but implementations of JasmineReporter that make a
  // JasmineRunner available should primarily be concerned about the observer methods.
}

/**
 * This interface is defined by https://github.com/jasmine/jasmine/blob/1_3_x/src/core/Spec.js.
 */
type JasmineSpec = {
  constructor(env: mixed, suite: JasmineSuite, description: string): void,
  getFullName(): string,
  results(): JasmineNestedResults,
}

/**
 * This interface is defined by https://github.com/jasmine/jasmine/blob/1_3_x/src/core/Suite.js.
 */
type JasmineSuite = {
  constructor(
    env: JasmineEnv,
    description: string,
    specDefinitions: Function,
    parentSuite: JasmineSuite,
  ): void,
  getFullName(): string,
  finish(onComplete: () => void): void,
  add(suiteOrSpec: JasmineSuite | JasmineSpec): void,
  specs(): JasmineSpec[],
  suites(): JasmineSuite[],
  children(): Array<JasmineSuite | JasmineSpec>,
  execute(onComplete: () => void): void,
}

/**
 * This interface is defined by https://github.com/jasmine/jasmine/blob/1_3_x/src/core/Reporter.js.
 */
type JasmineReporter = {
  /** This is invoked once when the runner starts up. */
  reportRunnerStarting(runner: JasmineRunner): void,

  /**
   * This will be invoked when the runner is completely finished. At this point, it makes sense to
   * inspect the runner.
   */
  reportRunnerResults(runner: JasmineRunner): void,

  /** As an example, TerminalReporter does not use this method. */
  reportSuiteResults(suite: JasmineSuite): void,

  /** As an example, TerminalReporter does not use this method. */
  reportSpecStarting(spec: JasmineSpec): void,

  /** This is frequently used to report streaming results. */
  reportSpecResults(spec: JasmineSpec): void,

  /** Reports a log message to print out. */
  log(str: string): void,
}

type TestRunnerOptions = {
  logFile: ?string,
};

type TestRunner = {
  execute(): void,
};

/**
 * @param logFile If specified, log messages from the test will be written to this file; otherwise,
 *   they will be written to stderr. (This only applies when tests are run from the terminal.)
 */
export default function runSpecSuite ({logFile}: TestRunnerOptions): TestRunner {
  let jasmineGlobals = require('../vendor/jasmine')
  for (let key in jasmineGlobals) {
    window[key] = jasmineGlobals[key]
  }

  // Loading this module has the side-effect of adding the setIncludedTags() method to jasmine.
  // This is why it must be done even if the TerminalReporter is not used.
  let {TerminalReporter} = require('jasmine-tagged')

  if (process.env.JANKY_SHA1 || process.env.CI) {
    disableFocusMethods()
  }

  let TimeReporter = require('./time-reporter')
  let timeReporter: JasmineReporter = new TimeReporter()

  let logStream = logFile ? fs.openSync(logFile, 'w') : null
  function log (str: string) {
    if (logStream) {
      fs.writeSync(logStream, str)
    } else {
      process.stderr.write(str)
    }
  }

  let reporter: JasmineReporter
  if (atom.getLoadSettings().exitWhenDone) {
    reporter = new TerminalReporter({
      print(str) {
        log(str)
      },

      onComplete(runner) {
        if (logStream) {
          fs.closeSync(logStream)
        }

        if (process.env.JANKY_SHA1) {
          let grim = require('grim')
          if (grim.getDeprecationsLength() > 0) {
            grim.logDeprecations()
            return atom.exit(1)
          }
        }

        let exitCode = runner.results().failedCount > 0 ? 1 : 0
        atom.exit(exitCode)
      },
    })
  } else {
    let AtomReporter = require('./atom-reporter')
    reporter = new AtomReporter()
  }

  require('./spec-suite')

  let jasmineEnv = jasmine.getEnv()
  jasmineEnv.addReporter(reporter)
  jasmineEnv.addReporter(timeReporter)
  jasmineEnv.setIncludedTags([process.platform])

  let jasmineContent = document.createElement('div')
  jasmineContent.setAttribute('id', 'jasmine-content')
  document.body.appendChild(jasmineContent)

  return jasmineEnv
}

function disableFocusMethods () {
  for (let methodName of ['fdescribe', 'ffdescribe', 'fffdescribe', 'fit', 'ffit', 'fffit']) {
    let focusMethod = window[methodName]
    window[methodName] = (description: string) => {
      let error = new Error('Focused spec is running on CI')
      focusMethod(description, () => { throw error })
    }
  }
}
