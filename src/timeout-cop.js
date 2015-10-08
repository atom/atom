'use strict'

let parentProcessId = process.argv[2]
let timeoutInMinutes = process.argv[3]
let timeoutInMilliseconds = timeoutInMinutes * 1000 * 60

function exitTestRunner () {
  process.kill(parentProcessId, 'SIGINT')
  let errorMessage = 'The test suite has timed out because it has been running'
  errorMessage += ' for more than ' + timeoutInMinutes + ' minutes.'
  console.log(errorMessage)
}

setTimeout(exitTestRunner, timeoutInMilliseconds)
