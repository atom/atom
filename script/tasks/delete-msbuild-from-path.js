'use strict';

const fs = require("fs");
const path = require("path");

const {taskify} = require("../lib/task");

module.exports = taskify("Delete MS Build from path", function() {
  process.env["PATH"] = process.env["PATH"]
    .split(";")
    .filter(function(p) {
      if (fs.existsSync(path.join(p, "msbuild.exe"))) {
        this.warn(
          'Excluding "' +
            p +
            '" from PATH to avoid msbuild.exe mismatch that causes errors during module installation'
        );
        return false;
      } else {
        return true;
      }
    })
    .join(';');
});
