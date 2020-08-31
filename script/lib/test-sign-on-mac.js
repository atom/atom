const spawnSync = require('./spawn-sync');

module.exports = function(packagedAppPath) {
  const result = spawnSync('security', [
    'find-certificate',
    '-c',
    'Mac Developer'
  ]);

  const certMatch = (result.stdout || '')
    .toString()
    .match(/"(Mac Developer.*\))"/);
  if (!certMatch || !certMatch[1]) {
    console.error(
      'A "Mac Developer" certificate must be configured to perform test signing'
    );
  } else {
    // This code-signs the application with a local certificate which won't be
    // useful anywhere else but the current machine
    // See this issue for more details: https://github.com/electron/electron/issues/7476#issuecomment-356084754
    console.log(`Found development certificate '${certMatch[1]}'`);
    console.log(`Test-signing application at ${packagedAppPath}`);
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
};
