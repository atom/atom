'use strict';

const fs = require('fs-extra');
const path = require('path');
const syncRequest = require('sync-request');

module.exports = function(downloadURL, destinationPath) {
  console.log(`Downloading file from GitHub Repository to ${destinationPath}`);
  const response = syncRequest('GET', downloadURL, {
    headers: {
      Accept: 'application/vnd.github.v3.raw',
      'User-Agent': 'Atom Build',
      Authorization: `token ${process.env.GITHUB_TOKEN}`
    }
  });

  if (response.statusCode === 200) {
    fs.mkdirpSync(path.dirname(destinationPath));
    fs.writeFileSync(destinationPath, response.body);
  } else {
    throw new Error(
      'Error downloading file. HTTP Status ' + response.statusCode + '.'
    );
  }
};
