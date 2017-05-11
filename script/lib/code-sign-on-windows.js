const downloadFileFromGithub = require('./download-file-from-github')
const fs = require('fs-extra')
const os = require('os')
const path = require('path')
const {spawnSync} = require('child_process')

// This is only used when specifying --code-sign WITHOUT --create-windows-installer
// as Squirrel has to take care of code-signing in order to correctly wrap during the building of setup

module.exports = function (packagedAppPath) {
  if (!process.env.ATOM_WIN_CODE_SIGNING_CERT_DOWNLOAD_URL && !process.env.ATOM_WIN_CODE_SIGNING_CERT_PATH) {
    console.log('Skipping code signing because the ATOM_WIN_CODE_SIGNING_CERT_DOWNLOAD_URL environment variable is not defined'.gray)
    return
  }

  let certPath = process.env.ATOM_WIN_CODE_SIGNING_CERT_PATH
  if (!certPath) {
    certPath = path.join(os.tmpdir(), 'win.p12')
    downloadFileFromGithub(process.env.ATOM_WIN_CODE_SIGNING_CERT_DOWNLOAD_URL, certPath)
  }
  try {
    console.log(`Code-signing application at ${packagedAppPath}`)
    signFile(path.join(packagedAppPath, 'atom.exe'))
  } finally {
    if (!process.env.ATOM_WIN_CODE_SIGNING_CERT_PATH) {
      console.log(`Deleting certificate at ${certPath}`)
      fs.removeSync(certPath)
    }
  }

  function signFile(filePath) {
    const signCommand = path.resolve(__dirname, '..', 'node_modules', 'electron-winstaller', 'vendor', 'signtool.exe')
    const args = [ // Changing any of these should also be done in create-windows-installer.js
      'sign',
      `/f ${certPath}`, // Signing cert file
      `/p ${process.env.ATOM_WIN_CODE_SIGNING_CERT_PASSWORD}`, // Signing cert password
      '/fd sha256', // File digest algorithm
      '/tr http://timestamp.digicert.com', // Time stamp server
      '/td sha256', // Times stamp algorithm
      `"${filePath}"`
    ]
    const result = spawnSync(signCommand, args, {stdio: 'inherit', shell: true})
    if (result.status !== 0) {
      // Ensure we do not dump the signing password into the logs if something goes wrong
      throw new Error(`Command ${signCommand} ${args.map(a => a.replace(process.env.ATOM_WIN_CODE_SIGNING_CERT_PASSWORD, '******')).join(' ')} exited with code ${result.status}`)
    }
  }
}
