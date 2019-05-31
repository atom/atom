'use strict';

const glob = require('glob');
const uploadToS3 = require('./lib/upload-to-s3');

const yargs = require('yargs');
const argv = yargs
  .usage('Usage: $0 [options]')
  .help('help')
  .describe(
    'crash-report-path',
    'The local path of a directory containing crash reports to upload'
  )
  .describe(
    's3-path',
    'Indicates the S3 path in which the crash reports should be uploaded'
  )
  .wrap(yargs.terminalWidth()).argv;

async function uploadCrashReports() {
  const crashesPath = argv.crashReportPath;
  const crashes = glob.sync('/*.dmp', { root: crashesPath });
  const bucketPath = argv.s3Path;

  if (crashes && crashes.length > 0) {
    console.log(
      `Uploading ${
        crashes.length
      } private crash reports to S3 under '${bucketPath}'`
    );

    await uploadToS3(
      process.env.ATOM_RELEASES_S3_KEY,
      process.env.ATOM_RELEASES_S3_SECRET,
      process.env.ATOM_RELEASES_S3_BUCKET,
      bucketPath,
      crashes,
      'private'
    );
  }
}

// Wrap the call the async function and catch errors from its promise because
// Node.js doesn't yet allow use of await at the script scope
uploadCrashReports().catch(err => {
  console.error('An error occurred while uploading crash reports:\n\n', err);
  process.exit(1);
});
