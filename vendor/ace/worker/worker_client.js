/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is Ajax.org Code Editor (ACE).
 *
 * The Initial Developer of the Original Code is
 * Ajax.org B.V.
 * Portions created by the Initial Developer are Copyright (C) 2010
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *      Fabian Jakobs <fabian AT ajax DOT org>
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */

define(function(require, exports, module) {
"use strict";

var oop = require("../lib/oop");
var EventEmitter = require("../lib/event_emitter").EventEmitter;

var WorkerClient = function(topLevelNamespaces, packagedJs, mod, classname) {

    this.changeListener = this.changeListener.bind(this);

    if (module.packaged) {
        var base = this.$guessBasePath();
        this.$worker = new Worker(base + packagedJs);
    }
    else {
        var workerUrl = this.$normalizePath(require.nameToUrl("ace/worker/worker", null, "_"));
        this.$worker = new Worker(workerUrl);

        var tlns = {};
        for (var i=0; i<topLevelNamespaces.length; i++) {
            var ns = topLevelNamespaces[i];
            var path = this.$normalizePath(require.nameToUrl(ns, null, "_").replace(/.js$/, ""));

            tlns[ns] = path;
        }
    }

    this.$worker.postMessage({
        init : true,
        tlns: tlns,
        module: mod,
        classname: classname
    });

    this.callbackId = 1;
    this.callbacks = {};

    var _self = this;
    this.$worker.onerror = function(e) {
        window.console && console.log && console.log(e);
        throw e;
    };
    this.$worker.onmessage = function(e) {
        var msg = e.data;
        switch(msg.type) {
            case "log":
                window.console && console.log && console.log(msg.data);
                break;

            case "event":
                _self._emit(msg.name, {data: msg.data});
                break;

            case "call":
                var callback = _self.callbacks[msg.id];
                if (callback) {
                    callback(msg.data);
                    delete _self.callbacks[msg.id];
                }
                break;
        }
    };
};

(function(){

    oop.implement(this, EventEmitter);

    this.$normalizePath = function(path) {
        path = path.replace(/^[a-z]+:\/\/[^\/]+\//, ""); // Remove domain name and rebuild it
        path = location.protocol + "//" + location.host
            // paths starting with a slash are relative to the root (host)
            + (path.charAt(0) == "/" ? "" : location.pathname.replace(/\/[^\/]*$/, ""))
            + "/" + path.replace(/^[\/]+/, "");
        return path;
    };

    this.$guessBasePath = function() {
        if (require.aceBaseUrl)
            return require.aceBaseUrl;

        var scripts = document.getElementsByTagName("script");
        for (var i=0; i<scripts.length; i++) {
            var script = scripts[i];

            var base = script.getAttribute("data-ace-base");
            if (base)
                return base.replace(/\/*$/, "/");

            var src = script.src || script.getAttribute("src");
            if (!src) {
                continue;
            }
            var m = src.match(/^(?:(.*\/)ace\.js|(.*\/)ace(-uncompressed)?(-noconflict)?\.js)(?:\?|$)/);
            if (m)
                return m[1] || m[2];
        }
        return "";
    };

    this.terminate = function() {
        this._emit("terminate", {});
        this.$worker.terminate();
        this.$worker = null;
        this.$doc.removeEventListener("change", this.changeListener);
        this.$doc = null;
    };

    this.send = function(cmd, args) {
        this.$worker.postMessage({command: cmd, args: args});
    };

    this.call = function(cmd, args, callback) {
        if (callback) {
            var id = this.callbackId++;
            this.callbacks[id] = callback;
            args.push(id);
        }
        this.send(cmd, args);
    };

    this.emit = function(event, data) {
        try {
            // firefox refuses to clone objects which have function properties
            // TODO: cleanup event
            this.$worker.postMessage({event: event, data: {data: data.data}});
        }
        catch(ex) {}
    };

    this.attachToDocument = function(doc) {
        if(this.$doc)
            this.terminate();

        this.$doc = doc;
        this.call("setValue", [doc.getValue()]);
        doc.on("change", this.changeListener);
    };

    this.changeListener = function(e) {
        e.range = {
            start: e.data.range.start,
            end: e.data.range.end
        };
        this.emit("change", e);
    };

}).call(WorkerClient.prototype);

exports.WorkerClient = WorkerClient;

});
