'use strict';

const glob = require('glob');
const uploadToAzure = require('./lib/upload-to-azure-blob');

const yargs = require('yargs');
const argv = yargs
  .usage('Usage: $0 [options]')
  .help('help')
  .describe(
    'crash-report-path',
    'The local path of a directory containing crash reports to upload'
  )
  .describe(
    'azure-blob-path',
    'Indicates the azure blob storage path in which the crash reports should be uploaded'
  )
  .wrap(yargs.terminalWidth()).argv;

async function uploadCrashReports() {
  const crashesPath = argv.crashReportPath;
  const crashes = glob.sync('/*.dmp', { root: crashesPath });
  const azureBlobPath = argv.azureBlobPath;

  if (crashes && crashes.length > 0) {
    console.log(
      `Uploading ${
        crashes.length
      } private crash reports to Azure Blob Storage under '${azureBlobPath}'`
    );

    await uploadToAzure(
      process.env.ATOM_RELEASES_AZURE_CONN_STRING,
      azureBlobPath,
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
