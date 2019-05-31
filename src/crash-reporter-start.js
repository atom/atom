module.exports = function(extra) {
  const { crashReporter } = require('electron');
  crashReporter.start({
    productName: 'Atom',
    companyName: 'GitHub',
    submitURL: 'https://crashreporter.atom.io',
    uploadToServer: false,
    extra: extra
  });
};
