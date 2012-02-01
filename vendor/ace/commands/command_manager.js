define(function(require, exports, module) {
"use strict";

var keyUtil = require("../lib/keys");

var CommandManager = function(platform, commands) {
    if (typeof platform !== "string")
        throw new TypeError("'platform' argument must be either 'mac' or 'win'");

    this.platform = platform;
    this.commands = {};
    this.commmandKeyBinding = {};

    if (commands)
        commands.forEach(this.addCommand, this);
};

(function() {

    this.addCommand = function(command) {
        if (this.commands[command.name])
            this.removeCommand(command);

        this.commands[command.name] = command;

        if (command.bindKey) {
            this._buildKeyHash(command);
        }
    };

    this.removeCommand = function(command) {
        var name = (typeof command === 'string' ? command : command.name);
        command = this.commands[name];
        delete this.commands[name];

        // exaustive search is brute force but since removeCommand is
        // not a performance critical operation this should be OK
        var ckb = this.commmandKeyBinding;
        for (var hashId in ckb) {
            for (var key in ckb[hashId]) {
                if (ckb[hashId][key] == command)
                    delete ckb[hashId][key];
            }
        }
    };

    this.addCommands = function(commands) {
        Object.keys(commands).forEach(function(name) {
            var command = commands[name];
            if (typeof command === "string")
                return this.bindKey(command, name);

            if (typeof command === "function")
                command = { exec: command };

            if (!command.name)
                command.name = name;

            this.addCommand(command);
        }, this);
    };

    this.removeCommands = function(commands) {
        Object.keys(commands).forEach(function(name) {
            this.removeCommand(commands[name]);
        }, this);
    };

    this.bindKey = function(key, command) {
        if(!key)
            return;

        var ckb = this.commmandKeyBinding;
        key.split("|").forEach(function(keyPart) {
            var binding = parseKeys(keyPart, command);
            var hashId = binding.hashId;
            (ckb[hashId] || (ckb[hashId] = {}))[binding.key] = command;
        });
    };

    this.bindKeys = function(keyList) {
        Object.keys(keyList).forEach(function(key) {
            this.bindKey(key, keyList[key]);
        }, this);
    };

    this._buildKeyHash = function(command) {
        var binding = command.bindKey;
        if (!binding)
            return;

        var key = typeof binding == "string" ? binding: binding[this.platform];
        this.bindKey(key, command);
    }

    function parseKeys(keys, val, ret) {
        var key;
        var hashId = 0;
        var parts = splitSafe(keys);

        for (var i=0, l = parts.length; i < l; i++) {
            if (keyUtil.KEY_MODS[parts[i]])
                hashId = hashId | keyUtil.KEY_MODS[parts[i]];
            else
                key = parts[i] || "-"; //when empty, the splitSafe removed a '-'
        }

        return {
            key: key,
            hashId: hashId
        }
    }

    function splitSafe(s, separator) {
        return (s.toLowerCase()
            .trim()
            .split(new RegExp("[\\s ]*\\-[\\s ]*", "g"), 999));
    }

    this.findKeyCommand = function findKeyCommand(hashId, textOrKey) {
        // Convert keyCode to the string representation.
        if (typeof textOrKey == "number") {
            textOrKey = keyUtil.keyCodeToString(textOrKey);
        }

        var ckbr = this.commmandKeyBinding;
        return ckbr[hashId] && ckbr[hashId][textOrKey.toLowerCase()];
    }

    this.exec = function(command, editor, args) {
        if (typeof command === 'string')
            command = this.commands[command];

        if (!command)
            return false;

        if (editor && editor.$readOnly && !command.readOnly)
            return false;

        command.exec(editor, args || {});
        return true;
    };

    this.toggleRecording = function() {
        if (this.$inReplay)
            return;
        if (this.recording) {
            this.macro.pop();
            this.exec = this.normal_exec;

            if (!this.macro.length)
                this.macro = this.oldMacro;

            return this.recording = false;
        }
        this.oldMacro = this.macro;
        this.macro = [];
        this.normal_exec = this.exec;
        this.exec = function(command, editor, args) {
            this.macro.push([command, args]);
            return this.normal_exec(command, editor, args);
        };
        return this.recording = true;
    };

    this.replay = function(editor) {
        if (this.$inReplay || !this.macro)
            return;

        if (this.recording)
            return this.toggleRecording();

        try {
            this.$inReplay = true;
            this.macro.forEach(function(x) {
                if (typeof x == "string")
                    this.exec(x, editor);
                else
                    this.exec(x[0], editor, x[1]);
            }, this)
        } finally {
            this.$inReplay = false;
        }
    };

    this.trimMacro = function(m) {
        return m.map(function(x){
            if (typeof x[0] != "string")
                x[0] = x[0].name;
            if (!x[1])
                x = x[0];
            return x
        })
    }

}).call(CommandManager.prototype);

exports.CommandManager = CommandManager;

});
