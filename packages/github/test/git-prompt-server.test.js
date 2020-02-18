import {execFile} from 'child_process';
import path from 'path';
import fs from 'fs-extra';

import GitPromptServer from '../lib/git-prompt-server';
import GitTempDir from '../lib/git-temp-dir';
import {fileExists, getAtomHelperPath} from '../lib/helpers';

describe('GitPromptServer', function() {
  const electronEnv = {
    ELECTRON_RUN_AS_NODE: '1',
    ELECTRON_NO_ATTACH_CONSOLE: '1',
    ATOM_GITHUB_KEYTAR_FILE: null,
    ATOM_GITHUB_DUGITE_PATH: require.resolve('dugite'),
    ATOM_GITHUB_KEYTAR_STRATEGY_PATH: require.resolve('../lib/shared/keytar-strategy'),
    ATOM_GITHUB_ORIGINAL_PATH: process.env.PATH,
    ATOM_GITHUB_WORKDIR_PATH: path.join(__dirname, '..'),
    ATOM_GITHUB_SPEC_MODE: 'true',
    GIT_TRACE: 'true',
    GIT_TERMINAL_PROMPT: '0',
  };

  let tempDir;

  beforeEach(async function() {
    tempDir = new GitTempDir();
    await tempDir.ensure();

    electronEnv.ATOM_GITHUB_KEYTAR_FILE = tempDir.getScriptPath('fake-keytar');
  });

  describe('credential helper', function() {
    let server, stderrData, stdoutData;

    beforeEach(function() {
      stderrData = [];
      stdoutData = [];
      server = new GitPromptServer(tempDir);
    });

    async function runCredentialScript(command, queryHandler, processHandler) {
      await server.start(queryHandler);

      return new Promise(resolve => {
        const child = execFile(
          getAtomHelperPath(), [tempDir.getCredentialHelperJs(), server.getAddress(), command],
          {env: electronEnv},
          (err, stdout, stderr) => {
            resolve({err, stdout, stderr});
          },
        );

        child.stdout.on('data', data => stdoutData.push(data));
        child.stderr.on('data', data => stderrData.push(data));

        processHandler(child);
      });
    }

    afterEach(async function() {
      if (this.currentTest.state === 'failed') {
        if (stderrData.length > 0 || stdoutData.length > 0) {
          /* eslint-disable no-console */
          console.log(this.currentTest.fullTitle());
          console.log(`STDERR:\n${stderrData.join('')}\n`);
          console.log(`STDOUT:\n${stdoutData.join('')}\n`);
          /* eslint-enable no-console */
        }
      }

      await tempDir.dispose();
    });

    it('prompts for user input and writes collected credentials to stdout', async function() {
      this.timeout(10000);

      let queried = null;

      function queryHandler(query) {
        queried = query;
        return {
          username: 'old-man-from-scene-24',
          password: 'Green. I mean blue! AAAhhhh...',
          remember: false,
        };
      }

      function processHandler(child) {
        child.stdin.write('protocol=https\n');
        child.stdin.write('host=what-is-your-favorite-color.com\n');
        child.stdin.end('\n');
      }

      const {err, stdout} = await runCredentialScript('get', queryHandler, processHandler);

      assert.equal(queried.prompt, 'Please enter your credentials for https://what-is-your-favorite-color.com');
      assert.isTrue(queried.includeUsername);

      assert.ifError(err);
      assert.equal(stdout,
        'protocol=https\nhost=what-is-your-favorite-color.com\n' +
        'username=old-man-from-scene-24\npassword=Green. I mean blue! AAAhhhh...\n' +
        'quit=true\n');

      assert.isFalse(await fileExists(tempDir.getScriptPath('remember')));
    });

    it('preserves a provided username', async function() {
      this.timeout(10000);

      let queried = null;

      function queryHandler(query) {
        queried = query;
        return {
          password: '42',
          remember: false,
        };
      }

      function processHandler(child) {
        child.stdin.write('protocol=https\n');
        child.stdin.write('host=ultimate-answer.com\n');
        child.stdin.write('username=dent-arthur-dent\n');
        child.stdin.end('\n');
      }

      const {err, stdout} = await runCredentialScript('get', queryHandler, processHandler);

      assert.ifError(err);

      assert.equal(queried.prompt, 'Please enter your credentials for https://dent-arthur-dent@ultimate-answer.com');
      assert.isFalse(queried.includeUsername);

      assert.equal(stdout,
        'protocol=https\nhost=ultimate-answer.com\n' +
        'username=dent-arthur-dent\npassword=42\n' +
        'quit=true\n');
    });

    it('parses input without the terminating blank line', async function() {
      this.timeout(10000);

      function queryHandler(query) {
        return {
          username: 'old-man-from-scene-24',
          password: 'Green. I mean blue! AAAhhhh...',
          remember: false,
        };
      }

      function processHandler(child) {
        child.stdin.write('protocol=https\n');
        child.stdin.write('host=what-is-your-favorite-color.com\n');
        child.stdin.end();
      }

      const {err, stdout} = await runCredentialScript('get', queryHandler, processHandler);

      assert.ifError(err);
      assert.equal(stdout,
        'protocol=https\nhost=what-is-your-favorite-color.com\n' +
        'username=old-man-from-scene-24\npassword=Green. I mean blue! AAAhhhh...\n' +
        'quit=true\n');
    });

    it('creates a flag file if remember is set to true', async function() {
      this.timeout(10000);

      function queryHandler() {
        return {
          username: 'old-man-from-scene-24',
          password: 'Green. I mean blue! AAAhhhh...',
          remember: true,
        };
      }

      function processHandler(child) {
        child.stdin.write('protocol=https\n');
        child.stdin.write('host=what-is-your-favorite-color.com\n');
        child.stdin.end('\n');
      }

      const {err} = await runCredentialScript('get', queryHandler, processHandler);
      assert.ifError(err);
      assert.isTrue(await fileExists(tempDir.getScriptPath('remember')));
    });

    it('uses matching credentials from keytar if available without prompting', async function() {
      this.timeout(10000);

      let called = false;
      function queryHandler() {
        called = true;
        return {};
      }

      function processHandler(child) {
        child.stdin.write('protocol=https\n');
        child.stdin.write('host=what-is-your-favorite-color.com\n');
        child.stdin.write('username=old-man-from-scene-24');
        child.stdin.end('\n');
      }

      await fs.writeFile(tempDir.getScriptPath('fake-keytar'), `
      {
        "atom-github-git @ https://what-is-your-favorite-color.com": {
          "old-man-from-scene-24": "swordfish",
          "github.com": "nope"
        },
        "atom-github-git @ https://github.com": {
          "old-man-from-scene-24": "nope"
        }
      }
      `, {encoding: 'utf8'});
      const {err, stdout} = await runCredentialScript('get', queryHandler, processHandler);
      assert.ifError(err);
      assert.isFalse(called);

      assert.equal(stdout,
        'protocol=https\nhost=what-is-your-favorite-color.com\n' +
        'username=old-man-from-scene-24\npassword=swordfish\n' +
        'quit=true\n');
    });

    it('uses a default username for the appropriate host if one is available', async function() {
      this.timeout(10000);

      let called = false;
      function queryHandler() {
        called = true;
        return {};
      }

      function processHandler(child) {
        child.stdin.write('protocol=https\n');
        child.stdin.write('host=what-is-your-favorite-color.com\n');
        child.stdin.end('\n');
      }

      await fs.writeFile(tempDir.getScriptPath('fake-keytar'), `
      {
        "atom-github-git-meta @ https://what-is-your-favorite-color.com": {
          "username": "old-man-from-scene-24"
        },
        "atom-github-git @ https://what-is-your-favorite-color.com": {
          "old-man-from-scene-24": "swordfish",
          "github.com": "nope"
        },
        "atom-github-git-meta @ https://github.com": {
          "username": "nah"
        },
        "atom-github-git @ https://github.com": {
          "old-man-from-scene-24": "nope"
        }
      }
      `, {encoding: 'utf8'});
      const {err, stdout} = await runCredentialScript('get', queryHandler, processHandler);
      assert.ifError(err);
      assert.isFalse(called);

      assert.equal(stdout,
        'protocol=https\nhost=what-is-your-favorite-color.com\n' +
        'username=old-man-from-scene-24\npassword=swordfish\n' +
        'quit=true\n');
    });

    it('uses credentials from the GitHub tab if available', async function() {
      this.timeout(10000);

      let called = false;
      function queryHandler() {
        called = true;
        return {};
      }

      function processHandler(child) {
        child.stdin.write('protocol=https\n');
        child.stdin.write('host=what-is-your-favorite-color.com\n');
        child.stdin.write('username=old-man-from-scene-24\n');
        child.stdin.end('\n');
      }

      await fs.writeFile(tempDir.getScriptPath('fake-keytar'), `
      {
        "atom-github": {
          "https://what-is-your-favorite-color.com": "swordfish"
        }
      }
      `, {encoding: 'utf8'});
      const {err, stdout} = await runCredentialScript('get', queryHandler, processHandler);
      assert.ifError(err);
      assert.isFalse(called);

      assert.equal(stdout,
        'protocol=https\nhost=what-is-your-favorite-color.com\n' +
        'username=old-man-from-scene-24\npassword=swordfish\n' +
        'quit=true\n');
    });

    it('stores credentials in keytar if a flag file is present', async function() {
      this.timeout(10000);

      let called = false;
      function queryHandler() {
        called = true;
        return {};
      }

      function processHandler(child) {
        child.stdin.write('protocol=https\n');
        child.stdin.write('host=what-is-your-favorite-color.com\n');
        child.stdin.write('username=old-man-from-scene-24\n');
        child.stdin.write('password=shhhh');
        child.stdin.end('\n');
      }

      await fs.writeFile(tempDir.getScriptPath('remember'), '', {encoding: 'utf8'});
      const {err} = await runCredentialScript('store', queryHandler, processHandler);
      assert.ifError(err);
      assert.isFalse(called);

      const stored = await fs.readFile(tempDir.getScriptPath('fake-keytar'), {encoding: 'utf8'});
      assert.deepEqual(JSON.parse(stored), {
        'atom-github-git-meta @ https://what-is-your-favorite-color.com': {
          username: 'old-man-from-scene-24',
        },
        'atom-github-git @ https://what-is-your-favorite-color.com': {
          'old-man-from-scene-24': 'shhhh',
        },
      });
    });

    it('forgets stored credentials from keytar if authentication fails', async function() {
      this.timeout(10000);

      function queryHandler() {
        return {};
      }

      function processHandler(child) {
        child.stdin.write('protocol=https\n');
        child.stdin.write('host=what-is-your-favorite-color.com\n');
        child.stdin.write('username=old-man-from-scene-24\n');
        child.stdin.write('password=shhhh');
        child.stdin.end('\n');
      }

      await fs.writeFile(tempDir.getScriptPath('fake-keytar'), JSON.stringify({
        'atom-github-git @ https://what-is-your-favorite-color.com': {
          'old-man-from-scene-24': 'shhhh',
          'someone-else': 'untouched',
        },
        'atom-github-git @ https://github.com': {
          'old-man-from-scene-24': 'untouched',
        },
      }), {encoding: 'utf8'});

      const {err} = await runCredentialScript('erase', queryHandler, processHandler);
      assert.ifError(err);

      const stored = await fs.readFile(tempDir.getScriptPath('fake-keytar'), {encoding: 'utf8'});
      assert.deepEqual(JSON.parse(stored), {
        'atom-github-git @ https://what-is-your-favorite-color.com': {
          'someone-else': 'untouched',
        },
        'atom-github-git @ https://github.com': {
          'old-man-from-scene-24': 'untouched',
        },
      });
    });

    afterEach(async function() {
      await server.terminate();
    });
  });

  describe('askpass helper', function() {
    it('prompts for user input and writes the response to stdout', async function() {
      this.timeout(10000);

      let queried = null;

      const server = new GitPromptServer(tempDir);
      await server.start(query => {
        queried = query;
        return {
          password: "What's 'updog'?",
        };
      });

      let err, stdout;
      await new Promise(resolve => {
        const child = execFile(
          getAtomHelperPath(), [tempDir.getAskPassJs(), server.getAddress(), 'Please enter your password for "updog"'],
          {env: electronEnv},
          (_err, _stdout, _stderr) => {
            err = _err;
            stdout = _stdout;
            resolve();
          },
        );

        child.stderr.on('data', console.log); // eslint-disable-line no-console
      });

      assert.ifError(err);
      assert.equal(stdout, "What's 'updog'?");

      assert.equal(queried.prompt, 'Please enter your password for "updog"');
      assert.isFalse(queried.includeUsername);

      await server.terminate();
    });
  });
});
