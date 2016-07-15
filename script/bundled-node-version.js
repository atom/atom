module.exports = function(filename, callback) {
  console.log('Executing bundled-node-version.js')
  console.trace()
  require('child_process').exec(filename + ' -v', function(error, stdout) {
    var version = null;
    if (stdout != null) {
      version = stdout.toString().trim();
    }
    callback(error, version);
  });
}
