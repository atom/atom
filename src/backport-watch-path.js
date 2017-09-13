// Backport single-file, stat-polling file watching from nsfw

const fs = require('fs-plus')
const {Disposable} = require('event-kit')

function stat (filePath) {
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

exports.watchPath = function (filePath, options, eventCallback) {
  let fileStat = null

  const getStatus = () => {
    stat(filePath).then(
      nextStat => {
        if (fileStat === null) {
          fileStat = nextStat
          eventCallback([{action: 'created', path: filePath}])
        } else if (nextStat.mtime - fileStat.mtime !== 0 || nextStat.ctime - fileStat.ctime !== 0) {
          fileStat = nextStat
          eventCallback([{action: 'modified', path: filePath}])
        }
      },
      () => {
        if (fileStat !== null) {
          fileStat = null
          eventCallback([{action: 'deleted', path: filePath}])
        }
      }
    )
  }

  return stat(filePath).then(
    nextStat => {
      fileStat = nextStat
    },
    () => {
      fileStat = null
    }
  ).then(() => {
    const pollInterval = setInterval(getStatus, INTERVAL)

    return new Disposable(() => {
      clearInterval(pollInterval)
      return Promise.resolve()
    })
  })
}
