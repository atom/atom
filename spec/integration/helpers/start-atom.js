const path = require('path');
const http = require('http');
const temp = require('temp').track();
const remote = require('remote');
const { once } = require('underscore-plus');
const { spawn } = require('child_process');
const webdriverio = require('../../../script/node_modules/webdriverio');

const AtomPath = remote.process.argv[0];
const AtomLauncherPath = path.join(
  __dirname,
  '..',
  'helpers',
  'atom-launcher.sh'
);
const ChromedriverPath = path.resolve(
  __dirname,
  '..',
  '..',
  '..',
  'script',
  'node_modules',
  'electron-chromedriver',
  'bin',
  'chromedriver'
);
const ChromedriverPort = 9515;
const ChromedriverURLBase = '/wd/hub';
const ChromedriverStatusURL = `http://localhost:${ChromedriverPort}${ChromedriverURLBase}/status`;

const chromeDriverUp = done => {
  const checkStatus = () =>
    http
      .get(ChromedriverStatusURL, response => {
        if (response.statusCode === 200) {
          done();
        } else {
          chromeDriverUp(done);
        }
      })
      .on('error', () => chromeDriverUp(done));

  setTimeout(checkStatus, 100);
};

const chromeDriverDown = done => {
  const checkStatus = () =>
    http
      .get(ChromedriverStatusURL, response => chromeDriverDown(done))
      .on('error', done);

  setTimeout(checkStatus, 100);
};

const buildAtomClient = async (args, env) => {
  // Since ChromeDriver v2.41, ChromeDriver will only connect if, either we precise a port
  // for remote debugging, either the embedder (ie electron) made sure to pass `USER_DATA_DIR`
  // to the remote debugging server.
  // So, for now, we'll just use a random port (we don't care about its value since we're not
  // connecting through it).
  // (inspired by https://github.com/electron/spectron/pull/361/commits/737db138bd8a6daaf80f9c2bff710ce4a5fff39b).
  // TodoElectronIssue: Remove the whole remote-debugging-port param once we upgrade
  // to Electron v5, since this was fixes there (see electron/electron#17800).
  const randomPort = Math.floor(Math.random() * (9999 - 9000) + 9000);

  const userDataDir = temp.mkdirSync('atom-user-data-dir');
  const client = await webdriverio.remote({
    host: 'localhost',
    port: ChromedriverPort,
    capabilities: {
      browserName: 'atom',
      chromeOptions: {
        binary: AtomLauncherPath,
        args: [
          `atom-path=${AtomPath}`,
          `atom-args=${args.join(' ')}`,
          `atom-env=${Object.entries(env)
            .map(([key, value]) => `${key}=${value}`)
            .join(' ')}`,
          'dev',
          'safe',
          `user-data-dir=${userDataDir}`,
          `remote-debugging-port=${randomPort}`
        ]
      }
    }
  });

  client.addCommand('waitForPaneItemCount', async function(count, timeout) {
    await this.waitUntil(
      () =>
        this.execute(() => atom.workspace.getActivePane().getItems().length),
      timeout
    );
  });
  client.addCommand('treeViewRootDirectories', async function() {
    const treeViewElement = await this.$('.tree-view');
    await treeViewElement.waitForExist(10000);
    return this.execute(() =>
      Array.from(
        document.querySelectorAll('.tree-view .project-root > .header .name')
      ).map(element => element.dataset.path)
    );
  });
  client.addCommand('dispatchCommand', async function(command) {
    return this.execute(
      command => atom.commands.dispatch(document.activeElement, command),
      command
    );
  });

  return client;
};

module.exports = function(args, env, fn) {
  let chromedriver, chromedriverLogs, chromedriverExit;

  runs(() => {
    chromedriver = spawn(ChromedriverPath, [
      '--verbose',
      `--port=${ChromedriverPort}`,
      `--url-base=${ChromedriverURLBase}`
    ]);

    chromedriverLogs = [];
    chromedriverExit = new Promise(resolve => {
      let errorCode = null;
      chromedriver.on('exit', (code, signal) => {
        if (signal == null) {
          errorCode = code;
        }
      });
      chromedriver.stderr.on('data', log =>
        chromedriverLogs.push(log.toString())
      );
      chromedriver.stderr.on('close', () => resolve(errorCode));
    });
  });

  waitsFor('webdriver to start', chromeDriverUp, 15000);

  waitsFor(
    'tests to run',
    async done => {
      const finish = once(async () => {
        await client.deleteSession();
        chromedriver.kill();

        const errorCode = await chromedriverExit;
        if (errorCode != null) {
          jasmine.getEnv().currentSpec
            .fail(`Chromedriver exited with code ${errorCode}.
Logs:\n${chromedriverLogs.join('\n')}`);
        }
        done();
      });

      let client;
      try {
        client = await buildAtomClient(args, env);
      } catch (error) {
        jasmine
          .getEnv()
          .currentSpec.fail(`Unable to build Atom client.\n${error}`);
        finish();
        return;
      }

      try {
        await client.waitUntil(async function() {
          const handles = await this.getWindowHandles();
          return handles.length > 0;
        }, 10000);
      } catch (error) {
        jasmine
          .getEnv()
          .currentSpec.fail(`Unable to locate windows.\n\n${error}`);
        finish();
        return;
      }

      try {
        const workspaceElement = await client.$('atom-workspace');
        await workspaceElement.waitForExist(10000);
      } catch (error) {
        jasmine
          .getEnv()
          .currentSpec.fail(`Unable to find workspace element.\n\n${error}`);
        finish();
        return;
      }

      try {
        await fn(client);
      } catch (error) {
        jasmine.getEnv().currentSpec.fail(error);
        finish();
        return;
      }
      finish();
    },
    60000
  );

  waitsFor('webdriver to stop', chromeDriverDown, 15000);
};
