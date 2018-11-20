/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

/*eslint-env mocha*/

const { ipcRenderer } = require('electron');
const assert = require('assert');
const path = require('path');
const glob = require('glob');
const minimatch = require('minimatch');
const istanbul = require('istanbul');
const i_remap = require('remap-istanbul/lib/remap');
const util = require('util');
const bootstrap = require('../../src/bootstrap');

// Disabled custom inspect. See #38847
if (util.inspect && util.inspect['defaultOptions']) {
	util.inspect['defaultOptions'].customInspect = false;
}

let _tests_glob = '**/test/**/*.test.js';
let loader;
let _out;

function initLoader(opts) {
	let outdir = opts.build ? 'out-build' : 'out';
	_out = path.join(__dirname, `../../${outdir}`);

	// setup loader
	loader = require(`${_out}/vs/loader`);
	const loaderConfig = {
		nodeRequire: require,
		nodeMain: __filename,
		catchError: true,
		baseUrl: bootstrap.uriFromPath(path.join(__dirname, '../../src')),
		paths: {
			'vs': `../${outdir}/vs`,
			'lib': `../${outdir}/lib`,
			'bootstrap-fork': `../${outdir}/bootstrap-fork`
		}
	};

	// nodeInstrumenter when coverage is requested
	if (opts.coverage) {
		const instrumenter = new istanbul.Instrumenter();

		loaderConfig.nodeInstrumenter = function (contents, source) {
			return minimatch(source, _tests_glob)
				? contents // don't instrument tests itself
				: instrumenter.instrumentSync(contents, source);
		};
	}

	loader.require.config(loaderConfig);
}

function createCoverageReport(opts) {
	return new Promise(resolve => {

		if (!opts.coverage) {
			return resolve(undefined);
		}

		const exclude = /\b((winjs\.base)|(marked)|(raw\.marked)|(nls)|(css))\.js$/;
		const remappedCoverage = i_remap(global.__coverage__, { exclude: exclude }).getFinalCoverage();

		// The remapped coverage comes out with broken paths
		function toUpperDriveLetter(str) {
			if (/^[a-z]:/.test(str)) {
				return str.charAt(0).toUpperCase() + str.substr(1);
			}
			return str;
		}
		function toLowerDriveLetter(str) {
			if (/^[A-Z]:/.test(str)) {
				return str.charAt(0).toLowerCase() + str.substr(1);
			}
			return str;
		}

		const REPO_PATH = toUpperDriveLetter(path.join(__dirname, '../..'));
		const fixPath = function (brokenPath) {
			const startIndex = brokenPath.indexOf(REPO_PATH);
			if (startIndex === -1) {
				return toLowerDriveLetter(brokenPath);
			}
			return toLowerDriveLetter(brokenPath.substr(startIndex));
		};

		const finalCoverage = Object.create(null);
		for (const entryKey in remappedCoverage) {
			const entry = remappedCoverage[entryKey];
			entry.path = fixPath(entry.path);
			finalCoverage[fixPath(entryKey)] = entry;
		}

		const collector = new istanbul.Collector();
		collector.add(finalCoverage);

		let coveragePath = path.join(path.dirname(__dirname), '../.build/coverage');
		let reportTypes = [];
		if (opts.run || opts.runGlob) {
			// single file running
			coveragePath += '-single';
			reportTypes = ['lcovonly'];
		} else {
			reportTypes = ['json', 'lcov', 'html'];
		}

		const reporter = new istanbul.Reporter(null, coveragePath);
		reporter.addAll(reportTypes);
		reporter.write(collector, true, resolve);
	});
}

function loadTestModules(opts) {

	if (opts.run) {
		const files = Array.isArray(opts.run) ? opts.run : [opts.run];
		const modules = files.map(file => {
			return path.relative(_out, file).replace(/\.js$/, '');
		});
		return new Promise((resolve, reject) => {
			loader.require(modules, resolve, reject);
		});
	}

	const pattern = opts.runGlob || _tests_glob;

	return new Promise((resolve, reject) => {
		glob(pattern, { cwd: _out }, (err, files) => {
			if (err) {
				reject(err);
				return;
			}
			const modules = files.map(file => file.replace(/\.js$/, ''));
			resolve(modules);
		});
	}).then(modules => {
		return new Promise((resolve, reject) => {
			loader.require(modules, resolve, reject);
		});
	});
}

function loadTests(opts) {

	const _unexpectedErrors = [];
	const _loaderErrors = [];

	// collect loader errors
	loader.require.config({
		onError(err) {
			_loaderErrors.push(err);
			console.error(err);
		}
	});

	// collect unexpected errors
	loader.require(['vs/base/common/errors'], function (errors) {
		errors.setUnexpectedErrorHandler(function (err) {
			let stack = (err ? err.stack : null);
			if (!stack) {
				stack = new Error().stack;
			}

			_unexpectedErrors.push((err && err.message ? err.message : err) + '\n' + stack);
		});
	});

	return loadTestModules(opts).then(() => {
		suite('Unexpected Errors & Loader Errors', function () {
			test('should not have unexpected errors', function () {
				const errors = _unexpectedErrors.concat(_loaderErrors);
				if (errors.length) {
					errors.forEach(function (stack) {
						console.error('');
						console.error(stack);
					});
					assert.ok(false, errors);
				}
			});
		});
	});
}

function serializeSuite(suite) {
	return {
		root: suite.root,
		suites: suite.suites.map(serializeSuite),
		tests: suite.tests.map(serializeRunnable),
		title: suite.title,
		fullTitle: suite.fullTitle(),
		timeout: suite.timeout(),
		retries: suite.retries(),
		enableTimeouts: suite.enableTimeouts(),
		slow: suite.slow(),
		bail: suite.bail()
	};
}

function serializeRunnable(runnable) {
	return {
		title: runnable.title,
		fullTitle: runnable.fullTitle(),
		async: runnable.async,
		slow: runnable.slow(),
		speed: runnable.speed,
		duration: runnable.duration
	};
}

function serializeError(err) {
	return {
		message: err.message,
		stack: err.stack,
		actual: err.actual,
		expected: err.expected,
		uncaught: err.uncaught,
		showDiff: err.showDiff,
		inspect: typeof err.inspect === 'function' ? err.inspect() : ''
	};
}

class IPCReporter {

	constructor(runner) {
		runner.on('start', () => ipcRenderer.send('start'));
		runner.on('end', () => ipcRenderer.send('end'));
		runner.on('suite', suite => ipcRenderer.send('suite', serializeSuite(suite)));
		runner.on('suite end', suite => ipcRenderer.send('suite end', serializeSuite(suite)));
		runner.on('test', test => ipcRenderer.send('test', serializeRunnable(test)));
		runner.on('test end', test => ipcRenderer.send('test end', serializeRunnable(test)));
		runner.on('hook', hook => ipcRenderer.send('hook', serializeRunnable(hook)));
		runner.on('hook end', hook => ipcRenderer.send('hook end', serializeRunnable(hook)));
		runner.on('pass', test => ipcRenderer.send('pass', serializeRunnable(test)));
		runner.on('fail', (test, err) => ipcRenderer.send('fail', serializeRunnable(test), serializeError(err)));
		runner.on('pending', test => ipcRenderer.send('pending', serializeRunnable(test)));
	}
}

function runTests(opts) {

	return loadTests(opts).then(() => {

		if (opts.grep) {
			mocha.grep(opts.grep);
		}

		if (!opts.debug) {
			mocha.reporter(IPCReporter);
		}

		const runner = mocha.run(() => {
			createCoverageReport(opts).then(() => {
				ipcRenderer.send('all done');
			});
		});

		if (opts.debug) {
			runner.on('fail', (test, err) => {

				console.error(test.fullTitle());
				console.error(err.stack);
			});
		}
	});
}

ipcRenderer.on('run', (e, opts) => {
	initLoader(opts);
	runTests(opts).catch(err => console.error(typeof err === 'string' ? err : JSON.stringify(err)));
});
