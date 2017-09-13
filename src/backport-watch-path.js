// Backport single-file, stat-polling file watching from nsfw

const fs = require('fs-plus')
const {Disposable} = require('event-kit')

function stat(filePath) {
  return new Promise((resolve, reject) => {
    fs.stat(filePath, (err, stat) => {
      if (err) {
        reject(err)
      } else {
        resolve(stat)
      }
    })
  })
}

const INTERVAL = 100

exports.watchPath = async function (filePath, options, eventCallback) {
  let fileStat = null
  let pollInterval = null

  const getStatus = async () => {
    try {
      const nextStat = await stat(filePath)
      if (fileStat === null) {
        fileStat = nextStat
        eventCallback([{action: 'created', path: filePath}])
      } else if (nextStat.mtime - fileStat.mtime !== 0 || nextStat.ctime - fileStat.ctime !== 0) {
        fileStat = nextStat
        eventCallback([{action: 'modified', path: filePath}])
      }
    } catch (e) {
      console.log('error', e)
      if (fileStat !== null) {
        fileStat = null
        eventCallback([{action: 'deleted', path: filePath}])
      }
    }
  }

  fileStat = await stat(filePath).catch(null)
  pollInterval = setInterval(getStatus, INTERVAL)

  return new Disposable(() => {
    clearInterval(pollInterval)
    return Promise.resolve()
  })
}
