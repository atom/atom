const spawnSync = require('./spawn-sync');
const { DefaultTask } = require('./task');

module.exports = function(packagedAppPath, task = new DefaultTask()) {
  task.start('Test sign on mac');

  task.log('Looking for certificate');

  const result = spawnSync('security', [
    'find-certificate',
    '-c',
    'Mac Developer'
  ]);

  const certMatch = (result.stdout || '')
    .toString()
    .match(/"(Mac Developer.*\))"/);
  if (!certMatch || !certMatch[1]) {
    task.error(
      'A "Mac Developer" certificate must be configured to perform test signing'
    );
  } else {
    // This code-signs the application with a local certificate which won't be
    // useful anywhere else but the current machine
    // See this issue for more details: https://github.com/electron/electron/issues/7476#issuecomment-356084754
    task.log(`Found development certificate '${certMatch[1]}'`);
    task.log(`Test-signing application at ${packagedAppPath}`);
    spawnSync(
      'codesign',
      [
        '--deep',
        '--force',
        '--verbose',
        '--sign',
        certMatch[1],
        packagedAppPath
      ],
      { stdio: 'inherit' }
    );
  }

  task.done();
};
