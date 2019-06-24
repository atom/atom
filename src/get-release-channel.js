module.exports = function(version) {
  // This matches stable, dev (with or without commit hash) and any other
  // release channel following the pattern '1.00.0-channel0'
  const match = version.match(/\d+\.\d+\.\d+(-([a-z]+)(\d+|-\w{4,})?)?$/);
  if (!match) {
    return 'unrecognized';
  } else if (match[2]) {
    return match[2];
  }

  return 'stable';
};
