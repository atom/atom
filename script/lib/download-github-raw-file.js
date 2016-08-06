const fs = require('fs-extra')
const syncRequest = require('sync-request')

module.exports = function (downloadURL, destinationPath) {
  console.log(`Dowloading raw file from GitHub Repository to ${destinationPath}`)
  const response = syncRequest('GET', downloadURL, {
    'headers': {'Accept': 'application/vnd.github.v3.raw', 'User-Agent': 'Atom Build'}
  })

  if (response.statusCode === 200) {
    fs.writeFileSync(destinationPath, response.body)
  } else {
    throw new Error('Error downloading file. HTTP Status ' + response.statusCode + '.')
  }
}
