module.exports = function shellEscape(argument) {
  if (/[^A-Za-z0-9_\/:=-]/.test(argument)) {
    argument = "'" + argument.replace(/'/g,"'\\''") + "'";
    argument = argument.replace(/^(?:'')+/g, '').replace(/\\'''/g, "\\'" );
  }
  return argument;
}
