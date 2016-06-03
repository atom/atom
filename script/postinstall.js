var path = require('path')
var cp = require('child_process')

var script = path.join(__dirname, 'postinstall')
if (process.platform.indexOf('win') === 0) {
  script += '.cmd'
} else {
  script += '.sh'
}
var child = cp.exec(script, [], {stdio: ['pipe', 'pipe', 'pipe']})
child.stderr.pipe(process.stderr)
child.stdout.pipe(process.stdout)
