import {createRunner} from '@atom/mocha-test-runner';
import chai from 'chai';
import chaiAsPromised from 'chai-as-promised';
import path from 'path';

import until from 'test-until';
import NYC from 'nyc';
import semver from 'semver';

chai.use(chaiAsPromised);
global.assert = chai.assert;

// Give tests that rely on filesystem event delivery lots of breathing room.
until.setDefaultTimeout(parseInt(process.env.UNTIL_TIMEOUT || '3000', 10));

if (process.env.ATOM_GITHUB_BABEL_ENV === 'coverage' && !process.env.NYC_CONFIG) {
  // Set up Istanbul in this process.
  // This mimics the argument parsing and setup performed in:
  //   https://github.com/istanbuljs/nyc/blob/v13.0.0/bin/nyc.js
  // And the process-under-test wrapping done by:
  //   https://github.com/istanbuljs/nyc/blob/v13.0.0/bin/wrap.js

  const configUtil = require('nyc/lib/config-util');

  const yargs = configUtil.buildYargs();
  const config = configUtil.loadConfig({}, path.join(__dirname, '..'));
  configUtil.addCommandsAndHelp(yargs);
  const argv = yargs.config(config).parse([]);

  argv.instrumenter = require.resolve('nyc/lib/instrumenters/noop');
  argv.reporter = 'lcovonly';
  argv.cwd = path.join(__dirname, '..');
  argv.tempDirectory = path.join(__dirname, '..', '.nyc_output');

  global._nyc = new NYC(argv);

  if (argv.clean) {
    global._nyc.reset();
  } else {
    global._nyc.createTempDirectory();
  }
  if (argv.all) {
    global._nyc.addAllFiles();
  }

  process.env.NYC_CONFIG = JSON.stringify(argv);
  process.env.NYC_CWD = path.join(__dirname, '..');
  process.env.NYC_ROOT_ID = global._nyc.rootId;
  process.env.NYC_INSTRUMENTER = argv.instrumenter;
  process.env.NYC_PARENT_PID = process.pid;

  process.isChildProcess = true;
  global._nyc.config._processInfo = {
    ppid: '0',
    root: global._nyc.rootId,
  };

  global._nyc.wrap();

  global._nycInProcess = true;
} else if (process.env.NYC_CONFIG) {
  // Istanbul is running us from a parent process. Simulate the wrap.js call in:
  //   https://github.com/istanbuljs/nyc/blob/v13.0.0/bin/wrap.js

  const parentPid = process.env.NYC_PARENT_PID || '0';
  process.env.NYC_PARENT_PID = process.pid;

  const config = JSON.parse(process.env.NYC_CONFIG);
  config.isChildProcess = true;
  config._processInfo = {
    ppid: parentPid,
    root: process.env.NYC_ROOT_ID,
  };
  global._nyc = new NYC(config);
  global._nyc.wrap();
}

const testSuffixes = process.env.ATOM_GITHUB_TEST_SUITE === 'snapshot' ? ['snapshot.js'] : ['test.js'];

module.exports = createRunner({
  htmlTitle: `GitHub Package Tests - pid ${process.pid}`,
  reporter: process.env.MOCHA_REPORTER || 'list',
  overrideTestPaths: [/spec$/, /test/],
  testSuffixes,
}, (mocha, {terminate}) => {
  // Ensure that we expect to be deployable to this version of Atom.
  const engineRange = require('../package.json').engines.atom;
  const atomEnv = global.buildAtomEnvironment();
  const atomVersion = atomEnv.getVersion();
  const atomReleaseChannel = atomEnv.getReleaseChannel();
  atomEnv.destroy();

  if (!semver.satisfies(semver.coerce(atomVersion), engineRange)) {
    process.stderr.write(
      `Atom version ${atomVersion} does not satisfy the range "${engineRange}" specified in package.json.\n` +
      `This version of atom/github is currently incompatible with the ${atomReleaseChannel} ` +
      'Atom release channel.\n',
    );

    terminate(0);
  }

  const Enzyme = require('enzyme');
  const Adapter = require('enzyme-adapter-react-16');
  Enzyme.configure({adapter: new Adapter()});

  require('mocha-stress');

  mocha.timeout(parseInt(process.env.MOCHA_TIMEOUT || '5000', 10));

  if (process.env.TEST_JUNIT_XML_PATH) {
    mocha.reporter(require('mocha-multi-reporters'), {
      reporterEnabled: 'mocha-junit-reporter, list',
      mochaJunitReporterReporterOptions: {
        mochaFile: process.env.TEST_JUNIT_XML_PATH,
        useFullSuiteTitle: true,
        suiteTitleSeparedBy: ' / ',
      },
    });
  }
});
