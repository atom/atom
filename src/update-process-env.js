/** @babel */

import fs from 'fs'
import child_process from 'child_process'

const ENVIRONMENT_VARIABLES_TO_PRESERVE = new Set([
  'NODE_ENV',
  'NODE_PATH',
  'ATOM_HOME',
  'ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT'
])

const PLATFORMS_KNOWN_TO_WORK = new Set([
  'darwin',
  'linux'
])

async function updateProcessEnv (launchEnv) {
  let envToAssign
  if (launchEnv && shouldGetEnvFromShell(launchEnv)) {
    envToAssign = await getEnvFromShell(launchEnv)
  } else if (launchEnv && launchEnv.PWD) {
    envToAssign = launchEnv
  }

  if (envToAssign) {
    for (let key in process.env) {
      if (!ENVIRONMENT_VARIABLES_TO_PRESERVE.has(key)) {
        delete process.env[key]
      }
    }

    for (let key in envToAssign) {
      if (!ENVIRONMENT_VARIABLES_TO_PRESERVE.has(key) || (!process.env[key] && envToAssign[key])) {
        process.env[key] = envToAssign[key]
      }
    }

    if (envToAssign.ATOM_HOME && fs.existsSync(envToAssign.ATOM_HOME)) {
      process.env.ATOM_HOME = envToAssign.ATOM_HOME
    }
  }
}

function shouldGetEnvFromShell (env) {
  if (!PLATFORMS_KNOWN_TO_WORK.has(process.platform)) {
    return false
  }

  if (!env || !env.SHELL || env.SHELL.trim() === '') {
    return false
  }

  if (env.ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT || process.env.ATOM_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT) {
    return false
  }

  return true
}

async function getEnvFromShell (env) {
  if (!shouldGetEnvFromShell(env)) {
    return null
  }

  let {stdout, error} = await new Promise((resolve) => {
    let childProcess
    let error
    let stdout = ''
    const killer = () => {
      if (childProcess) {
        childProcess.kill()
      }
    }
    process.once('exit', killer)

    childProcess = child_process.spawn(env.SHELL, ['-ilc', 'command env'], {encoding: 'utf8', timeout: 5000, detached: true, stdio: ['ignore', 'pipe', process.stderr]})

    const buffers = []
    childProcess.on('error', (e) => {
      error = e
    })
    childProcess.stdout.on('data', (data) => {
      buffers.push(data)
    })
    childProcess.on('close', (code, signal) => {
      process.removeListener('exit', killer)
      if (buffers.length) {
        stdout = Buffer.concat(buffers).toString('utf8')
      }

      resolve({stdout, error})
    })
  })

  if (error) {
    if (error.handle) {
      error.handle()
    }
    console.log('warning: ' + env.SHELL + ' -ilc "command env" failed with signal (' + error.signal + ')')
    console.log(error)
  }

  if (stdout && stdout.trim() !== '') {
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

export default { updateProcessEnv, shouldGetEnvFromShell }
