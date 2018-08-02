const path = require('path')
const request = require('request-promise-native')

const repositoryRootPath = path.resolve(__dirname, '..', '..')
const appMetadata = require(path.join(repositoryRootPath, 'package.json'))

const yargs = require('yargs')
const argv = yargs
  .usage('Usage: $0 [options]')
  .help('help')
  .describe('nightly', 'Indicates that a nightly version should be produced')
  .wrap(yargs.terminalWidth())
  .argv

async function getReleaseVersion () {
  let releaseVersion = appMetadata.version
  if (argv.nightly) {
    const releases = await request({
      url: 'https://api.github.com/repos/atom/atom-nightly-releases/releases',
      headers: {'Accept': 'application/vnd.github.v3+json', 'User-Agent': 'Atom Release Build'},
      json: true
    })

    let releaseNumber = 0
    const baseVersion = appMetadata.version.split('-')[0]
    if (releases && releases.length > 0) {
      const latestRelease = releases.find(r => !r.draft)
      const versionMatch = latestRelease.tag_name.match(/^v?(\d+\.\d+\.\d+)-nightly(\d+)$/)

      if (versionMatch && versionMatch[1] === baseVersion) {
        releaseNumber = parseInt(versionMatch[2]) + 1
      }
    }

    releaseVersion = `${baseVersion}-nightly${releaseNumber}`
  }

  // Set our ReleaseVersion build variable and update VSTS' build number to
  // include the version.  Writing these strings to stdout causes VSTS to set
  // the associated variables.
  console.log(`##vso[task.setvariable variable=ReleaseVersion;isOutput=true]${releaseVersion}`)
  console.log(`##vso[build.updatebuildnumber]${releaseVersion}+${process.env.BUILD_BUILDNUMBER}`)

  // Write out some variables that indicate whether artifacts should be uploaded
  const buildBranch = process.env.BUILD_SOURCEBRANCHNAME
  const isReleaseBranch = process.env.IS_RELEASE_BRANCH || buildBranch.match(/\d\.\d+-releases/) !== null
  const isSignedZipBranch =
    process.env.IS_SIGNED_ZIP_BRANCH ||
    buildBranch.startsWith('electron-') ||
    buildBranch === 'master' && !process.env.SYSTEM_PULLREQUEST_PULLREQUESTNUMBER
  console.log(`##vso[task.setvariable variable=IsReleaseBranch;isOutput=true]${isReleaseBranch}`)
  console.log(`##vso[task.setvariable variable=IsSignedZipBranch;isOutput=true]${isSignedZipBranch}`)
}

getReleaseVersion()
