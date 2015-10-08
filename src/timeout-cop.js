var parentProcessId = process.argv[2];
var timeoutInMinutes = process.argv[3];
var timeoutInMilliseconds = timeoutInMinutes * 1000 * 60

function exitTestRunner() {
  process.kill(parentProcessId, "SIGINT");
  var errorMessage = "The test suite has timed out because it has been running";
  errorMessage += " for more than " + timeoutInMinutes + " minutes.";
  console.log(errorMessage);
}

setTimeout(exitTestRunner, timeoutInMilliseconds);
