'use strict'

const publishRelease = require('publish-release')
const CONFIG = require('../config')

module.exports = function (assets) {
  return new Promise(function (resolve, reject) {
    console.log(`Uploading assets to GitHub release ${CONFIG.computedAppVersion}`)
    publishRelease({
      token: process.env.GITHUB_TOKEN,
      owner: 'atom',
      repo: CONFIG.channel !== 'nightly' ? 'atom' : 'atom-nightly-releases',
      name: CONFIG.computedAppVersion,
      tag: CONFIG.computedAppVersion,
      draft: true,
      prerelease: CONFIG.channel !== 'stable',
      reuseRelease: true,
      reuseDraftOnly: true,
      skipIfPublished: true,
      assets
    }, function (err, release) {
      if (err) {
        reject(err)
      } else {
        console.log('Release created successfully: ', release.html_url)
        resolve(release)
      }
    })
  })
}
