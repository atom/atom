const semver = require('semver')
const changelog = require('pr-changelog')
const octokit = require('@octokit/rest')()

module.exports.get = async function(releaseVersion, githubToken) {
  if (githubToken) {
    octokit.authenticate({
      type: 'oauth',
      token: githubToken
    })
  }

  let releases = await octokit.repos.getReleases({owner: 'atom', repo: 'atom'})
  let release = releases.data.find(r => semver.eq(r.name, releaseVersion))
  return release ? release.body : undefined
}

module.exports.generate = async function(releaseVersion, githubToken) {
  let oldVersion = null
  let oldVersionName = null
  const parsedVersion = semver.parse(releaseVersion)
  const newVersionBranch = getBranchForVersion(parsedVersion)

  if (githubToken) {
    changelog.setGithubAccessToken(githubToken)
    octokit.authenticate({
      type: 'oauth',
      token: githubToken
    })
  }

  if (parsedVersion.prerelease && parsedVersion.prerelease[0] === 'beta0') {
    // For beta0 releases, stable hasn't been released yet so compare against
    // the stable version's release branch
    oldVersion = `${parsedVersion.major}.${parsedVersion.minor - 1}-releases`
    oldVersionName = `v${parsedVersion.major}.${parsedVersion.minor - 1}.0`
  } else {
    let releases = await octokit.repos.getReleases({owner: 'atom', repo: 'atom'})
    let versions = releases.data.map(r => r.name)
    oldVersion = 'v' + getPreviousVersion(releaseVersion, versions)
    oldVersionName = oldVersion
  }

  const allChangesText = await changelog.getChangelog({
    owner: 'atom',
    repo: 'atom',
    fromTag: oldVersion,
    toTag: newVersionBranch,
    dependencyKey: 'packageDependencies',
    changelogFormatter: function ({pullRequests, owner, repo, fromTag, toTag}) {
      let prString = changelog.pullRequestsToString(pullRequests)
      let title = repo
      if (repo === 'atom') {
        title = 'Atom Core'
        fromTag = oldVersionName
        toTag = releaseVersion
      }
      return `### [${title}](https://github.com/${owner}/${repo})\n\n${fromTag}...${toTag}\n\n${prString}`
    }
  })

  return `## Notable Changes\n\n\
**TODO**: Pull relevant changes here!\n\n\
<details>
<summary>All Changes</summary>\n\n
${allChangesText}\n\n
</details>
`
}

function getPreviousVersion (version, allVersions) {
  const versionIsStable = semver.prerelease(version) === null

  // Make sure versions are sorted before using them
  allVersions.sort(semver.rcompare)

  for (let otherVersion of allVersions) {
    if (versionIsStable && semver.prerelease(otherVersion)) {
      continue
    }

    if (semver.lt(otherVersion, version)) {
      return otherVersion
    }
  }

  return null
}

function getBranchForVersion (version) {
  let parsedVersion = version
  if (!(version instanceof semver.SemVer)) {
    parsedVersion = semver.parse(version)
  }

  return `${parsedVersion.major}.${parsedVersion.minor}-releases`
}
