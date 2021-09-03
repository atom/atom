const createRunner = require('atom-mocha-test-runner').createRunner;
module.exports = createRunner({ testSuffixes: ['test.js'] });
