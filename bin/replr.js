#!/usr/bin/env node
var argv = require('yargs').argv;
var keypress = require('keypress');
var merge = require('merge');
var net = require('net');

module.exports = startReplrClient;
module.exports.attachStdinStdoutToReplStream = attachStdinStdoutToReplStream;

if (require.main === module) {
    var options = {};
    if (argv._.length >= 1) {
        options.host = argv._[0];
    }
    if (argv._.length >= 2) {
        options.port = parseInt(argv._[1]);
        if (isNaN(options.port)) {
            delete options.port;
        }
    }
    startReplrClient(options);
}

function startReplrClient(options) {
    options = options || {};
    options = merge({
        host: 'localhost',
        port: 2323,
        mode: 'http',
        url: '/replr'
    }, options);
    var socket = net.connect(options, function onConnect() {
        socket.on('end', function onSocketEnd() {
            console.log('Server closed connection');
            process.exit(0);
        });
        if (options.mode === 'http') {
            socket.write('GET ' + options.url + ' HTTP/1.1\r\n' +
               'Upgrade: replr\r\n' +
               'Connection: Upgrade\r\n' +
               '\r\n');
        }
        attachStdinStdoutToReplStream(socket);
    });
}

function attachStdinStdoutToReplStream(stream) {
    keypress(process.stdin);
    process.stdin.on('keypress', function onKeypress(ch, key) {
        if (ch) {
            stream.write(ch);
            if (ch === '\r') {
                ch = '\n';
            } else if (ch === '\t') {
                // Tab completion
                ch = '';
            }
            process.stdout.write(ch);
        } else if (key) {
            stream.write(key.sequence);
        }

        var isCtrlC = key && key.ctrl && key.name === 'c';
        var isCtrlD = key && key.ctrl && key.name === 'd';
        if (isCtrlC || isCtrlD) {
            process.exit(0);
        }
    });
    process.stdin.setRawMode(true);
    process.stdin.resume();
    stream.pipe(process.stdout);
    return stream;
}
