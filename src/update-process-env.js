/** @babel */

import {spawnSync} from 'child_process'

const ENVIRONMENT_VARIABLES_TO_PRESERVE = new Set(['NODE_ENV', 'NODE_PATH'])

export default function updateProcessEnv (launchEnv) {
  let envToAssign
  if (launchEnv.PWD) {
    envToAssign = launchEnv
  } else {
    if (process.platform === 'darwin') {
      envToAssign = getEnvFromShell()
    }
  }

  if (envToAssign) {
    for (let key in process.env) {
      if (!ENVIRONMENT_VARIABLES_TO_PRESERVE.has(key)) {
        delete process.env[key]
      }
    }

    for (let key in envToAssign) {
      if (!ENVIRONMENT_VARIABLES_TO_PRESERVE.has(key)) {
        process.env[key] = envToAssign[key]
      }
    }
  }
}

function getEnvFromShell () {
  let shell = process.env.SHELL
  if (shell && (shell.endsWith('/bash') || shell.endsWith('/sh'))) {
    let {stdout} = spawnSync(shell, ['-ilc', 'env'], {encoding: 'utf8'})
    if (stdout) {
      let result = {}
      for (let line of stdout.split('\n')) {
        if (line.includes('=')) {
          let components = line.split('=')
          let key = components.shift()
          let value = components.join('=')
          result[key] = value
        }
      }
      return result
    }
  }
}
