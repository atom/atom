#!/usr/bin/env node

'use strict';

require('colors');
const argv = require('yargs')
  .option('core-main', {
    describe: 'Run core main process tests',
    boolean: true,
    default: false
  })
  .option('skip-main', {
    describe:
      'Skip main process tests if they would otherwise run on your platform',
    boolean: true,
    default: false,
    conflicts: 'core-main'
  })
  .option('core-renderer', {
    describe: 'Run core renderer process tests',
    boolean: true,
    default: false
  })
  .option('core-benchmark', {
    describe: 'Run core benchmarks',
    boolean: true,
    default: false
  })
  .option('package', {
    describe: 'Run bundled package specs',
    boolean: true,
    default: false
  })
  .help().argv;

const assert = require('assert');
const asyncSeries = require('async/series');
const childProcess = require('child_process');
const fs = require('fs-extra');
const glob = require('glob');
const path = require('path');
const temp = require('temp').track();

const CONFIG = require('./config');
const backupNodeModules = require('./lib/backup-node-modules');
const runApmInstall = require('./lib/run-apm-install');

function assertExecutablePaths(executablePaths) {
  assert(
    executablePaths.length !== 0,
    `No atom build found. Please run "script/build" and try again.`
  );
  assert(
    executablePaths.length === 1,
    `More than one application to run tests against was found. ${executablePaths.join(
      ','
    )}`
  );
}

const resourcePath = CONFIG.repositoryRootPath;
let executablePath;
if (process.platform === 'darwin') {
  const executablePaths = glob.sync(path.join(CONFIG.buildOutputPath, '*.app'));
  assertExecutablePaths(executablePaths);
  executablePath = path.join(
    executablePaths[0],
    'Contents',
    'MacOS',
    path.basename(executablePaths[0], '.app')
  );
} else if (process.platform === 'linux') {
  const executablePaths = glob.sync(
    path.join(CONFIG.buildOutputPath, 'atom-*', 'atom')
  );
  assertExecutablePaths(executablePaths);
  executablePath = executablePaths[0];
} else if (process.platform === 'win32') {
  const executablePaths = glob.sync(
    path.join(CONFIG.buildOutputPath, '**', 'atom*.exe')
  );
  assertExecutablePaths(executablePaths);
  executablePath = executablePaths[0];
} else {
  throw new Error('##[error] Running tests on this platform is not supported.');
}

function prepareEnv(suiteName) {
  const atomHomeDirPath = temp.mkdirSync(suiteName);
  const env = Object.assign({}, process.env, { ATOM_HOME: atomHomeDirPath });

  if (process.env.TEST_JUNIT_XML_ROOT) {
    // Tell Jasmine to output this suite's results as a JUnit XML file to a subdirectory of the root, so that a
    // CI system can interpret it.
    const fileName = suiteName + '.xml';
    const outputPath = path.join(process.env.TEST_JUNIT_XML_ROOT, fileName);
    env.TEST_JUNIT_XML_PATH = outputPath;
  }

  return env;
}

function spawnTest(
  executablePath,
  testArguments,
  options,
  callback,
  testName,
  finalize = null
) {
  const cp = childProcess.spawn(executablePath, testArguments, options);

  // collect outputs and errors
  let stderrOutput = '';
  if (cp.stdout) {
    cp.stderr.on('data', data => {
      stderrOutput += data;
    });
    cp.stdout.on('data', data => {
      stderrOutput += data;
    });
  }

  // on error
  cp.on('error', error => {
    console.log(error, 'error');
    if (finalize) {
      finalize();
    } // if finalizer provided
    callback(error);
  });

  // on close
  cp.on('close', exitCode => {
    if (exitCode !== 0) {
      retryOrFailTest(
        stderrOutput,
        exitCode,
        executablePath,
        testArguments,
        options,
        callback,
        testName,
        finalize
      );
    } else {
      // successful test
      if (finalize) {
        finalize();
      } // if finalizer provided
      callback(null, {
        exitCode,
        step: testName,
        testCommand: `You can run the test again using: \n\t ${executablePath} ${testArguments.join(
          ' '
        )}`
      });
    }
  });
}

const retryNumber = 6; // the number of times a tests repeats
const retriedTests = new Map(); // a cache of retried tests

// Retries the tests if it is timed out for a number of times. Fails the rest of the tests or those that are tried enough times.
function retryOrFailTest(
  stderrOutput,
  exitCode,
  executablePath,
  testArguments,
  options,
  callback,
  testName,
  finalize
) {
  const testKey = createTestKey(executablePath, testArguments, testName);
  if (isTimedOut(stderrOutput) && shouldTryAgain(testKey)) {
    // retry the timed out test
    let triedNumber = retriedTests.get(testKey) || 0;
    retriedTests.set(testKey, triedNumber + 1);
    console.warn(`\n##[warning] Retrying the timed out step: ${testName} \n`);
    spawnTest(
      executablePath,
      testArguments,
      options,
      callback,
      testName,
      finalize
    );
  } else {
    // fail the test
    if (finalize) {
      finalize();
    } // if finalizer provided
    console.log(`##[error] Tests for ${testName} failed.`.red);
    console.log(stderrOutput);
    callback(null, {
      exitCode,
      step: testName,
      testCommand: `You can run the test again using: \n\t ${executablePath} ${testArguments.join(
        ' '
      )}`
    });
  }
}

// creates a key that is specific to a certain test
function createTestKey(executablePath, testArguments, testName) {
  return `${executablePath} ${testArguments.join(' ')} ${testName}`;
}

// check if a test is timed out
function isTimedOut(stderrOutput) {
  if (stderrOutput) {
    return (
      stderrOutput.includes('timeout: timed out after') || // happens in core renderer tests
      stderrOutput.includes('Error: Timed out waiting on') || // happens in core renderer tests
      stderrOutput.includes('Error: timeout of') || // happens in core main tests
      stderrOutput.includes(
        'Error Downloading Update: Could not get code signature for running application'
      ) // happens in github tests
    );
  } else {
    return false;
  }
}

// check if a tests should be tried again
function shouldTryAgain(testKey) {
  if (retriedTests.has(testKey)) {
    return retriedTests.get(testKey) < retryNumber;
  } else {
    return true;
  }
}

function runCoreMainProcessTests(callback) {
  const testPath = path.join(CONFIG.repositoryRootPath, 'spec', 'main-process');
  const testArguments = [
    '--resource-path',
    resourcePath,
    '--test',
    '--main-process',
    testPath
  ];

  if (process.env.CI && process.platform === 'linux') {
    testArguments.push('--no-sandbox');
  }

  const testEnv = Object.assign({}, prepareEnv('core-main-process'), {
    ATOM_GITHUB_INLINE_GIT_EXEC: 'true'
  });

  console.log('##[command] Executing core main process tests'.bold.green);
  spawnTest(
    executablePath,
    testArguments,
    { stdio: 'inherit', env: testEnv },
    callback,
    'core-main-process'
  );
}

function getCoreRenderProcessTestSuites() {
  // Build an array of functions, each running tests for a different rendering test
  const coreRenderProcessTestSuites = [];
  const testPath = path.join(CONFIG.repositoryRootPath, 'spec');
  let testFiles = glob.sync(
    path.join(testPath, '*-spec.+(js|coffee|ts|jsx|tsx|mjs)')
  );
  for (let testFile of testFiles) {
    const testArguments = ['--resource-path', resourcePath, '--test', testFile];
    // the function which runs by async:
    coreRenderProcessTestSuites.push(function(callback) {
      const testEnv = prepareEnv('core-render-process');
      console.log(
        `##[command] Executing core render process tests for ${testFile}`.bold
          .green
      );
      spawnTest(
        executablePath,
        testArguments,
        { env: testEnv },
        callback,
        `core-render-process in ${testFile}.`
      );
    });
  }

  return coreRenderProcessTestSuites;
}

function getPackageTestSuites() {
  // Build an array of functions, each running tests for a different bundled package
  const packageTestSuites = [];
  for (let packageName in CONFIG.appMetadata.packageDependencies) {
    if (process.env.ATOM_PACKAGES_TO_TEST) {
      const packagesToTest = process.env.ATOM_PACKAGES_TO_TEST.split(',').map(
        pkg => pkg.trim()
      );
      if (!packagesToTest.includes(packageName)) continue;
    }

    const repositoryPackagePath = path.join(
      CONFIG.repositoryRootPath,
      'node_modules',
      packageName
    );
    const testSubdir = ['spec', 'test'].find(subdir =>
      fs.existsSync(path.join(repositoryPackagePath, subdir))
    );

    if (!testSubdir) {
      console.log(`No test folder found for package: ${packageName}`.yellow);
      continue;
    }

    const testFolder = path.join(repositoryPackagePath, testSubdir);

    const testArguments = [
      '--resource-path',
      resourcePath,
      '--test',
      testFolder
    ];

    const pkgJsonPath = path.join(repositoryPackagePath, 'package.json');
    const nodeModulesPath = path.join(repositoryPackagePath, 'node_modules');

    // the function which runs by async:
    packageTestSuites.push(function(callback) {
      const testEnv = prepareEnv(`bundled-package-${packageName}`);
      let finalize = () => null;
      if (require(pkgJsonPath).atomTestRunner) {
        console.log(
          `##[command] Installing test runner dependencies for ${packageName}`
            .bold.green
        );
        if (fs.existsSync(nodeModulesPath)) {
          const backup = backupNodeModules(repositoryPackagePath);
          finalize = backup.restore;
        } else {
          finalize = () => fs.removeSync(nodeModulesPath);
        }
        runApmInstall(repositoryPackagePath);
        console.log(`##[command] Executing ${packageName} tests`.green);
      } else {
        console.log(`##[command] Executing ${packageName} tests`.bold.green);
      }
      spawnTest(
        executablePath,
        testArguments,
        { env: testEnv },
        callback,
        `${packageName} package`,
        finalize
      );
    });
  }

  return packageTestSuites;
}

function runBenchmarkTests(callback) {
  const benchmarksPath = path.join(CONFIG.repositoryRootPath, 'benchmarks');
  const testArguments = ['--benchmark-test', benchmarksPath];
  const testEnv = prepareEnv('benchmark');

  console.log('##[command] Executing benchmark tests'.bold.green);
  spawnTest(
    executablePath,
    testArguments,
    { stdio: 'inherit', env: testEnv },
    callback,
    `core-benchmarks`
  );
}

let testSuitesToRun = requestedTestSuites(process.platform);

function requestedTestSuites(platform) {
  // env variable or argv options
  let coreAll = process.env.ATOM_RUN_CORE_TESTS === 'true';
  let coreMain =
    process.env.ATOM_RUN_CORE_MAIN_TESTS === 'true' || argv.coreMain;
  let coreRenderer =
    argv.coreRenderer || process.env.ATOM_RUN_CORE_RENDER_TESTS === 'true';
  let coreRenderer1 = process.env.ATOM_RUN_CORE_RENDER_TESTS === '1';
  let coreRenderer2 = process.env.ATOM_RUN_CORE_RENDER_TESTS === '2';
  let packageAll =
    argv.package || process.env.ATOM_RUN_PACKAGE_TESTS === 'true';
  let packages1 = process.env.ATOM_RUN_PACKAGE_TESTS === '1';
  let packages2 = process.env.ATOM_RUN_PACKAGE_TESTS === '2';
  let benchmark = argv.coreBenchmark;

  // Operating system overrides:
  coreMain =
    coreMain ||
    platform === 'linux' ||
    (platform === 'win32' && process.arch === 'x86');

  // split package tests (used for macos in CI)
  const PACKAGES_TO_TEST_IN_PARALLEL = 23;
  // split core render test (used for windows x64 in CI)
  const CORE_RENDER_TO_TEST_IN_PARALLEL = 45;

  let suites = [];
  // Core tess
  if (coreAll) {
    suites.push(
      ...[runCoreMainProcessTests, ...getCoreRenderProcessTestSuites()]
    );
  } else {
    // Core main tests
    if (coreMain) {
      suites.push(runCoreMainProcessTests);
    }

    // Core renderer tests
    if (coreRenderer) {
      suites.push(...getCoreRenderProcessTestSuites());
    } else {
      // split
      if (coreRenderer1) {
        suites.push(
          ...getCoreRenderProcessTestSuites().slice(
            0,
            CORE_RENDER_TO_TEST_IN_PARALLEL
          )
        );
      }
      if (coreRenderer2) {
        suites.push(
          ...getCoreRenderProcessTestSuites().slice(
            CORE_RENDER_TO_TEST_IN_PARALLEL
          )
        );
      }
    }
  }

  // Package tests
  if (packageAll) {
    suites.push(...getPackageTestSuites());
  } else {
    // split
    if (packages1) {
      suites.push(
        ...getPackageTestSuites().slice(0, PACKAGES_TO_TEST_IN_PARALLEL)
      );
    }
    if (packages2) {
      suites.push(
        ...getPackageTestSuites().slice(PACKAGES_TO_TEST_IN_PARALLEL)
      );
    }
  }

  // Benchmark tests
  if (benchmark) {
    suites.push(runBenchmarkTests);
  }

  if (argv.skipMainProcessTests) {
    suites = suites.filter(suite => suite !== runCoreMainProcessTests);
  }

  // Remove duplicates
  suites = Array.from(new Set(suites));

  if (suites.length === 0) {
    throw new Error('No tests was requested');
  }

  return suites;
}

asyncSeries(testSuitesToRun, function(err, results) {
  if (err) {
    console.error(err);
    process.exit(1);
  } else {
    const failedSteps = results.filter(({ exitCode }) => exitCode !== 0);

    if (failedSteps.length > 0) {
      console.warn(
        '\n \n ##[error] *** Reporting the errors that happened in all of the tests: *** \n \n'
      );
      for (const { step, testCommand } of failedSteps) {
        console.error(
          `##[error] The '${step}' test step finished with a non-zero exit code \n ${testCommand}`
        );
      }
      process.exit(1);
    }

    process.exit(0);
  }
});
