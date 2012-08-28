(function () {

native function sendMessageToBrowserProcess(name, array);
native function open(path);

this.atom = {
  sendMessageToBrowserProcess: sendMessageToBrowserProcess,
  open: open
};

})();
