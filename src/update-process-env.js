const fs = require('fs');
const childProcess = require('child_process');

const ENVIRONMENT_VARIABLES_TO_PRESERVE = new Set([
  'NODE_ENV',
  'NODE_PATH',
  'ATOM_HOME',
  'ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT'
]);

const PLATFORMS_KNOWN_TO_WORK = new Set(['darwin', 'linux']);

async function updateProcessEnv(launchEnv) {
  let envToAssign;
  if (launchEnv) {
    if (shouldGetEnvFromShell(launchEnv)) {
      envToAssign = await getEnvFromShell(launchEnv);
    } else if (launchEnv.PWD || launchEnv.PROMPT || launchEnv.PSModulePath) {
      envToAssign = launchEnv;
    }
  }

  if (envToAssign) {
    for (let key in process.env) {
      if (!ENVIRONMENT_VARIABLES_TO_PRESERVE.has(key)) {
        delete process.env[key];
      }
    }

    for (let key in envToAssign) {
      if (
        !ENVIRONMENT_VARIABLES_TO_PRESERVE.has(key) ||
        (!process.env[key] && envToAssign[key])
      ) {
        process.env[key] = envToAssign[key];
      }
    }

    if (envToAssign.ATOM_HOME && fs.existsSync(envToAssign.ATOM_HOME)) {
      process.env.ATOM_HOME = envToAssign.ATOM_HOME;
    }
  }
}

function shouldGetEnvFromShell(env) {
  if (!PLATFORMS_KNOWN_TO_WORK.has(process.platform)) {
    return false;
  }

  if (!env || !env.SHELL || env.SHELL.trim() === '') {
    return false;
  }

  const disableSellingOut =
    env.ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT ||
    process.env.ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT;

  if (disableSellingOut === 'true') {
    return false;
  }

  return true;
}

async function getEnvFromShell(env) {
  let { stdout, error } = await new Promise(resolve => {
    let child;
    let error;
    let stdout = '';
    let done = false;
    const cleanup = () => {
      if (!done && child) {
        child.kill();
        done = true;
      }
    };
    process.once('exit', cleanup);
    setTimeout(() => {
      cleanup();
    }, 5000);
    child = childProcess.spawn(env.SHELL, ['-ilc', 'command env'], {
      encoding: 'utf8',
      detached: true,
      stdio: ['ignore', 'pipe', process.stderr]
    });
    const buffers = [];
    child.on('error', e => {
      done = true;
      error = e;
    });
    child.stdout.on('data', data => {
      buffers.push(data);
    });
    child.on('close', (code, signal) => {
      done = true;
      process.removeListener('exit', cleanup);
      if (buffers.length) {
        stdout = Buffer.concat(buffers).toString('utf8');
      }

      resolve({ stdout, error });
    });
  });

  if (error) {
    if (error.handle) {
      error.handle();
    }
    console.log(
      'warning: ' +
        env.SHELL +
        ' -ilc "command env" failed with signal (' +
        error.signal +
        ')'
    );
    console.log(error);
  }

  if (!stdout || stdout.trim() === '') {
    return null;
  }

  let result = {};
  for (let line of stdout.split('\n')) {
    if (line.includes('=')) {
      let components = line.split('=');
      let key = components.shift();
      let value = components.join('=');
      result[key] = value;
    }
  }
  return result;
}

module.exports = { updateProcessEnv, shouldGetEnvFromShell };
