const path = require('path')
const request = require('request-promise-native')

const repositoryRootPath = path.resolve(__dirname, '..', '..')
const appMetadata = require(path.join(repositoryRootPath, 'package.json'))
const baseVersion = appMetadata.version.split('-')[0]

async function generateNightlyVersion () {
  const releases = await request({
    url: 'https://api.github.com/repos/atom/atom-nightly-releases/releases',
    headers: {'Accept': 'application/vnd.github.v3+json', 'User-Agent': 'Atom Release Build'},
    json: true
  })

  let releaseNumber = 0
  if (releases && releases.length > 0) {
    const latestRelease = releases.find(r => !r.draft)
    const versionMatch = latestRelease.tag_name.match(/^v?(\d+\.\d+\.\d+)-nightly(\d+)$/)

    if (versionMatch && versionMatch[1] === baseVersion) {
      releaseNumber = parseInt(versionMatch[2]) + 1
    }
  }

  // Set our ReleaseVersion build variable and update VSTS' build number to
  // include the version.  Writing these strings to stdout causes VSTS to set
  // the associated variables.
  const generatedVersion = `${baseVersion}-nightly${releaseNumber}`
  console.log(`##vso[task.setvariable variable=ReleaseVersion;isOutput=true]${generatedVersion}`)
  console.log(`##vso[build.updatebuildnumber]${generatedVersion}+${process.env.BUILD_BUILDNUMBER}`)
}

generateNightlyVersion()
