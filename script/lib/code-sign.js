module.exports = async function (packagedAppPath, argv) {
  switch (process.platform) {
    case 'darwin':
      const codeSignOnMac = require('./code-sign-on-mac')

      if (argv.codeSign) {
        codeSignOnMac(packagedAppPath)
      } else {
        console.log('Skipping code-signing. Specify the --code-sign option to perform code-signing'.gray)
      }
      break
    case 'win32':
      const codeSignOnWindows = require('./code-sign-on-windows')
      const createWindowsInstaller = require('./create-windows-installer')

      if (argv.codeSign) {
        const executablesToSign = [ path.join(packagedAppPath, 'Atom.exe') ]
        if (argv.createWindowsInstaller) {
          executablesToSign.push(path.join(__dirname, 'node_modules', 'electron-winstaller', 'vendor', 'Update.exe'))
        }
        codeSignOnWindows(executablesToSign)
      } else {
        console.log('Skipping code-signing. Specify the --code-sign option to perform code-signing'.gray)
      }
      if (argv.createWindowsInstaller) {
        const installerPath = await createWindowsInstaller(packagedAppPath)
        if (argv.codeSign) {
          codeSignOnWindows([installerPath])
        }
      } else {
        console.log('Skipping creating installer. Specify the --create-windows-installer option to create a Squirrel-based Windows installer.'.gray)
      }
      break
    case 'linux':
      const createDebianPackage = require('./create-debian-package')
      const createRpmPackage = require('./create-rpm-package')

      if (argv.createDebianPackage) {
        createDebianPackage(packagedAppPath)
      } else {
        console.log('Skipping creating debian package. Specify the --create-debian-package option to create it.'.gray)
      }

      if (argv.createRpmPackage) {
        createRpmPackage(packagedAppPath)
      } else {
        console.log('Skipping creating rpm package. Specify the --create-rpm-package option to create it.'.gray)
      }
      break
  }
}
