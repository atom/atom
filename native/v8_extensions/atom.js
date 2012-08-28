(function () {

native function sendMessageToBrowserProcess(name, array);

this.atom = {
  sendMessageToBrowserProcess: sendMessageToBrowserProcess
};

})();
