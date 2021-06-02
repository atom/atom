'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const glob = require('glob');
const spawnSync = require('../lib/spawn-sync');
const publishRelease = require('publish-release');
const releaseNotes = require('./lib/release-notes');
const uploadToAzure = require('./lib/upload-to-azure-blob');
const uploadLinuxPackages = require('./lib/upload-linux-packages');

const CONFIG = require('../config');

const yargs = require('yargs');
const argv = yargs
  .usage('Usage: $0 [options]')
  .help('help')
  .describe(
    'assets-path',
    'Path to the folder where all release assets are stored'
  )
  .describe(
    'azure-blob-path',
    'Indicates the Azure Blob Path path in which the assets should be uploaded'
  )
  .describe(
    'create-github-release',
    'Creates a GitHub release for this build, draft if release branch or public if Nightly'
  )
  .describe(
    'linux-repo-name',
    'If specified, uploads Linux packages to the given repo name on packagecloud'
  )
  .wrap(yargs.terminalWidth()).argv;

const releaseVersion = CONFIG.computedAppVersion;
const isNightlyRelease = CONFIG.channel === 'nightly';
const assetsPath = argv.assetsPath || CONFIG.buildOutputPath;
const assetsPattern =
  '/**/*(*.exe|*.zip|*.nupkg|*.tar.gz|*.rpm|*.deb|RELEASES*|atom-api.json)';
const assets = glob.sync(assetsPattern, { root: assetsPath, nodir: true });
const azureBlobPath = argv.azureBlobPath || `releases/v${releaseVersion}/`;

if (!assets || assets.length === 0) {
  console.error(`No assets found under specified path: ${assetsPath}`);
  process.exit(1);
}

async function uploadArtifacts() {
  let releaseForVersion = await releaseNotes.getRelease(
    releaseVersion,
    process.env.GITHUB_TOKEN
  );

  if (releaseForVersion.exists && !releaseForVersion.isDraft) {
    console.log(
      `Published release already exists for ${releaseVersion}, skipping upload.`
    );
    return;
  }

  console.log(
    `Uploading ${
      assets.length
    } release assets for ${releaseVersion} to Azure Blob Storage under '${azureBlobPath}'`
  );

  await uploadToAzure(
    process.env.ATOM_RELEASES_AZURE_CONN_STRING,
    azureBlobPath,
    assets
  );

  if (argv.linuxRepoName) {
    await uploadLinuxPackages(
      argv.linuxRepoName,
      process.env.PACKAGE_CLOUD_API_KEY,
      releaseVersion,
      assets
    );
  } else {
    console.log(
      '\nNo Linux package repo name specified, skipping Linux package upload.'
    );
  }

  const oldReleaseNotes = releaseForVersion.releaseNotes;
  if (oldReleaseNotes) {
    const oldReleaseNotesPath = path.resolve(
      os.tmpdir(),
      'OLD_RELEASE_NOTES.md'
    );
    console.log(
      `Saving existing ${releaseVersion} release notes to ${oldReleaseNotesPath}`
    );
    fs.writeFileSync(oldReleaseNotesPath, oldReleaseNotes, 'utf8');

    // This line instructs VSTS to upload the file as an artifact
    console.log(
      `##vso[artifact.upload containerfolder=OldReleaseNotes;artifactname=OldReleaseNotes;]${oldReleaseNotesPath}`
    );
  }

  if (argv.createGithubRelease) {
    console.log(`\nGenerating new release notes for ${releaseVersion}`);
    let newReleaseNotes = '';
    if (isNightlyRelease) {
      newReleaseNotes = await releaseNotes.generateForNightly(
        releaseVersion,
        process.env.GITHUB_TOKEN,
        oldReleaseNotes
      );
    } else {
      newReleaseNotes = await releaseNotes.generateForVersion(
        releaseVersion,
        process.env.GITHUB_TOKEN,
        oldReleaseNotes
      );
    }

    console.log(`New release notes:\n\n${newReleaseNotes}`);

    const releaseSha = !isNightlyRelease
      ? spawnSync('git', ['rev-parse', 'HEAD'])
          .stdout.toString()
          .trimEnd()
      : 'master'; // Nightly tags are created in atom/atom-nightly-releases so the SHA is irrelevant

    console.log(`Creating GitHub release v${releaseVersion}`);
    const release = await publishReleaseAsync({
      token: process.env.GITHUB_TOKEN,
      owner: 'atom',
      repo: !isNightlyRelease ? 'atom' : 'atom-nightly-releases',
      name: CONFIG.computedAppVersion,
      notes: newReleaseNotes,
      target_commitish: releaseSha,
      tag: `v${CONFIG.computedAppVersion}`,
      draft: !isNightlyRelease,
      prerelease: CONFIG.channel !== 'stable',
      editRelease: true,
      reuseRelease: true,
      skipIfPublished: true,
      assets
    });

    console.log('Release published successfully: ', release.html_url);
  } else {
    console.log('Skipping GitHub release creation');
  }
}

async function publishReleaseAsync(options) {
  return new Promise((resolve, reject) => {
    publishRelease(options, (err, release) => {
      if (err) {
        reject(err);
      } else {
        resolve(release);
      }
    });
  });
}

// Wrap the call the async function and catch errors from its promise because
// Node.js doesn't yet allow use of await at the script scope
uploadArtifacts().catch(err => {
  console.error('An error occurred while uploading the release:\n\n', err);
  process.exit(1);
});
