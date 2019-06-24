module.exports = function(params) {
  const { crashReporter } = require('electron');
  const platformRelease = require('os').release();
  const { uploadToServer } = params;

  crashReporter.start({
    productName: 'Atom',
    companyName: 'GitHub',
    submitURL: 'https://atom.io/crash_reports',
    uploadToServer,
    extra: { platformRelease }
  });
};
