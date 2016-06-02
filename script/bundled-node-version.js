module.exports = function(filename, callback) {
  require('child_process').exec(filename + ' -v', function(error, stdout) {
    var version = null;
    if (stdout != null) {
      version = stdout.toString().trim();
    }
    callback(error, version);
  });
}
