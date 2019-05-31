let startTime;
let markers = [];

module.exports = {
  setStartTime() {
    if (!startTime) {
      startTime = Date.now();
    }
  },
  addMarker(label, dateTime) {
    if (!startTime) {
      return;
    }

    dateTime = dateTime || Date.now();
    markers.push({ label, time: dateTime - startTime });
  },
  importData(data) {
    startTime = data.startTime;
    markers = data.markers;
  },
  exportData() {
    if (!startTime) {
      return undefined;
    }

    return { startTime, markers };
  },
  deleteData() {
    startTime = undefined;
    markers = [];
  }
};
