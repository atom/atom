const semver = require('semver');
const octokit = require('@octokit/rest')();
const changelog = require('pr-changelog');
const childProcess = require('child_process');

module.exports.getRelease = async function(releaseVersion, githubToken) {
  if (githubToken) {
    octokit.authenticate({
      type: 'oauth',
      token: githubToken
    });
  }

  const releases = await octokit.repos.getReleases({
    owner: 'atom',
    repo: 'atom'
  });
  const release = releases.data.find(r => semver.eq(r.name, releaseVersion));

  return {
    exists: release !== undefined,
    isDraft: release && release.draft,
    releaseNotes: release ? release.body : undefined
  };
};

module.exports.generateForVersion = async function(
  releaseVersion,
  githubToken,
  oldReleaseNotes
) {
  let oldVersion = null;
  let oldVersionName = null;
  const parsedVersion = semver.parse(releaseVersion);
  const newVersionBranch = getBranchForVersion(parsedVersion);

  if (githubToken) {
    changelog.setGithubAccessToken(githubToken);
    octokit.authenticate({
      type: 'oauth',
      token: githubToken
    });
  }

  if (parsedVersion.prerelease && parsedVersion.prerelease[0] === 'beta0') {
    // For beta0 releases, stable hasn't been released yet so compare against
    // the stable version's release branch
    oldVersion = `${parsedVersion.major}.${parsedVersion.minor - 1}-releases`;
    oldVersionName = `v${parsedVersion.major}.${parsedVersion.minor - 1}.0`;
  } else {
    let releases = await octokit.repos.getReleases({
      owner: 'atom',
      repo: 'atom'
    });
    oldVersion = 'v' + getPreviousRelease(releaseVersion, releases.data).name;
    oldVersionName = oldVersion;
  }

  const allChangesText = await changelog.getChangelog({
    owner: 'atom',
    repo: 'atom',
    fromTag: oldVersion,
    toTag: newVersionBranch,
    dependencyKey: 'packageDependencies',
    changelogFormatter: function({
      pullRequests,
      owner,
      repo,
      fromTag,
      toTag
    }) {
      let prString = changelog.pullRequestsToString(pullRequests);
      let title = repo;
      if (repo === 'atom') {
        title = 'Atom Core';
        fromTag = oldVersionName;
        toTag = releaseVersion;
      }
      return `### [${title}](https://github.com/${owner}/${repo})\n\n${fromTag}...${toTag}\n\n${prString}`;
    }
  });

  const writtenReleaseNotes =
    extractWrittenReleaseNotes(oldReleaseNotes) ||
    '**TODO**: Pull relevant changes here!';

  return `## Notable Changes\n
${writtenReleaseNotes}\n
<details>
<summary>All Changes</summary>\n
${allChangesText}
</details>
`;
};

module.exports.generateForNightly = async function(
  releaseVersion,
  githubToken
) {
  const releases = await octokit.repos.getReleases({
    owner: 'atom',
    repo: 'atom-nightly-releases'
  });
  const previousRelease = getPreviousRelease(releaseVersion, releases.data);
  const oldReleaseNotes = previousRelease ? previousRelease.body : undefined;

  const latestCommitResult = childProcess.spawnSync('git', [
    'rev-parse',
    '--short',
    'HEAD'
  ]);

  if (latestCommitResult && oldReleaseNotes) {
    const latestCommit = latestCommitResult.stdout.toString().trim();
    const extractMatch = oldReleaseNotes.match(
      /atom\/atom\/compare\/([0-9a-f]{5,40})\.\.\.([0-9a-f]{5,40})/
    );
    if (extractMatch) {
      return `### Click [here](https://github.com/atom/atom/compare/${
        extractMatch[2]
      }...${latestCommit}) to see the changes included with this release! :atom: :night_with_stars:`;
    }
  }

  return undefined;
};

function extractWrittenReleaseNotes(oldReleaseNotes) {
  if (oldReleaseNotes) {
    const extractMatch = oldReleaseNotes.match(
      /^## Notable Changes\r\n([\s\S]*)<details>/
    );
    if (extractMatch && extractMatch[1]) {
      return extractMatch[1].trim();
    }
  }

  return undefined;
}

function getPreviousRelease(version, allReleases) {
  const versionIsStable = semver.prerelease(version) === null;

  // Make sure versions are sorted before using them
  allReleases.sort((v1, v2) => semver.rcompare(v1.name, v2.name));

  for (let release of allReleases) {
    if (versionIsStable && semver.prerelease(release.name)) {
      continue;
    }

    if (semver.lt(release.name, version)) {
      return release;
    }
  }

  return null;
}

function getBranchForVersion(version) {
  let parsedVersion = version;
  if (!(version instanceof semver.SemVer)) {
    parsedVersion = semver.parse(version);
  }

  return `${parsedVersion.major}.${parsedVersion.minor}-releases`;
}
