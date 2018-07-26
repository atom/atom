const path = require('path')

const repositoryRootPath = path.resolve(__dirname, '..', '..')
const appMetadata = require(path.join(repositoryRootPath, 'package.json'))
const releaseVersion = appMetadata.version

// Set our ReleaseVersion build variable and update VSTS' build number to
// include the version.  Writing these strings to stdout causes VSTS to set
// the associated variables.
console.log(`##vso[task.setvariable variable=ReleaseVersion;isOutput=true]${releaseVersion}`)
console.log(`##vso[build.updatebuildnumber]${releaseVersion}+${process.env.BUILD_BUILDNUMBER}`)
