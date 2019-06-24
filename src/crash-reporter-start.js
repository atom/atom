module.exports = function(params) {
  const { crashReporter } = require('electron');
  const { uploadToServer, appVersion } = params;

  crashReporter.start({
    productName: 'Atom',
    companyName: 'GitHub',
    submitURL: 'https://atom.io/crash_reports',
    uploadToServer,
    extra: {
      appVersion
    }
  });
};
