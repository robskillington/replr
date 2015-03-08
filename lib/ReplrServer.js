// Generated by CoffeeScript 1.6.3
(function() {
  var EventEmitter, MemoryStream, ReplrClient, ReplrEvents, ReplrServer, Util, async, cluster, colors, merge, net, portscanner, repl, terminal,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  repl = require('repl');

  net = require('net');

  merge = require('merge');

  cluster = require('cluster');

  colors = require('colors');

  terminal = require('terminal');

  async = require('async');

  EventEmitter = require('events').EventEmitter;

  MemoryStream = require('memorystream');

  portscanner = require('portscanner');

  ReplrClient = require('./ReplrClient');

  ReplrEvents = require('./ReplrEvents');

  Util = require('./Util');

  ReplrServer = (function(_super) {
    __extends(ReplrServer, _super);

    ReplrServer.prototype.OPTIONS_DEFAULT = {
      name: 'Replr',
      port: 2323,
      prompt: 'replr> '.grey,
      terminal: false,
      useColors: false,
      describeWorker: null
    };

    ReplrServer.prototype.OPTIONS_REPL_KEYS = ['port', 'prompt', 'terminal', 'useColors', 'useGlobal', 'ignoreUndefined'];

    function ReplrServer(options, start) {
      if (start == null) {
        start = true;
      }
      options = options || {};
      if (options.port) {
        if (typeof options.port === 'number') {
          if (!Util.prototype.isInt(options.port) || options.port < 1) {
            throw new Error('bad port');
          }
        } else if (typeof options.port !== 'string') {
          throw new Error('bad port');
        }
      }
      if (options.prompt) {
        if (typeof options.prompt !== 'string') {
          throw new Error('bad prompt');
        }
      }
      this.options = merge(this.OPTIONS_DEFAULT, options);
      this.clients = [];
      this.started = false;
      this.starting = false;
      if (start) {
        return this.start();
      } else {
        return this;
      }
    }

    ReplrServer.prototype.start = function(callback) {
      var onVerified,
        _this = this;
      if (this.starting) {
        return;
      }
      this.starting = true;
      onVerified = function(err, status) {
        var onError;
        if (err || status === 'open') {
          if (callback) {
            callback(err || new Error('Port already taken'));
          }
          return;
        }
        _this.socketServer = net.createServer(_this.open.bind(_this));
        _this.socketServer.on('listening', function() {
          _this.started = true;
          _this.starting = false;
          return _this.emit('listening');
        });
        onError = function(err) {
          if (callback) {
            return callback(err);
          }
        };
        _this.socketServer.once('error', onError);
        try {
          _this.socketServer.listen(_this.options.port);
        } catch (_error) {
          err = _error;
          _this.started = false;
          _this.starting = false;
          if (callback) {
            callback(err);
          }
        }
        return _this.socketServer.removeListener('error', onError);
      };
      if (typeof this.options.port === 'number') {
        return portscanner.checkPortStatus(this.options.port, '127.0.0.1', onVerified);
      } else {
        return onVerified(null, 'free');
      }
    };

    ReplrServer.prototype.close = function(callback) {
      var _this = this;
      if (this.starting) {
        return this.once('listening', function() {
          return _this.close(callback);
        });
      } else if (this.started) {
        return this.socketServer.close(function() {
          _this.started = false;
          _this.emit('close');
          if (callback) {
            return callback();
          }
        });
      } else {
        return callback(new Error('Already closed'));
      }
    };

    ReplrServer.prototype.open = function(socket) {
      var client, exports, key, originalValue, r, replOptions, value, _i, _len, _ref, _ref1,
        _this = this;
      replOptions = {};
      _ref = this.OPTIONS_REPL_KEYS;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        key = _ref[_i];
        if (this.options.hasOwnProperty(key)) {
          replOptions[key] = this.options[key];
        }
      }
      replOptions.input = socket;
      replOptions.output = socket;
      r = repl.start(replOptions);
      r.on('exit', function() {
        return socket.end();
      });
      client = new ReplrClient(this, this.options, socket, r);
      this.clients.push(client);
      socket.on('error', function(err) {
        if (err && err.code === 'EPIPE') {
          return;
        }
        throw err;
      });
      socket.on('end', function() {
        return _this.clients.splice(_this.clients.indexOf(client), 1);
      });
      r.context.exported = {};
      _ref1 = client.exports();
      for (key in _ref1) {
        value = _ref1[key];
        r.context.exported[key] = value;
        r.context[key] = value;
      }
      if (this.options.exports && typeof this.options.exports === 'function') {
        exports = this.options.exports(client);
        if (exports && Object.keys(exports).length > 0) {
          for (key in exports) {
            value = exports[key];
            if (typeof value === 'function') {
              originalValue = value;
              value = value.bind(r.context);
              value.unbound = originalValue;
            }
            r.context.exported[key] = value;
            r.context[key] = value;
          }
        }
      }
      return client.welcome();
    };

    ReplrServer.prototype.forwardToWorker = function(client, worker) {
      var dummy, msg;
      msg = {
        type: ReplrEvents.prototype.WORKER_RECEIVE,
        options: this.options
      };
      dummy = new MemoryStream();
      client.repl.inputStream = dummy;
      client.repl.outputStream = dummy;
      client.repl.rli.input = dummy;
      client.repl.rli.output = dummy;
      return worker.send(msg, client.socket);
    };

    ReplrServer.prototype.describeWorkers = function(callback) {
      var formatTitle, id, worker, workersArray,
        _this = this;
      formatTitle = function(id, worker) {
        return "[" + id + "] id=" + id + ", pid=" + worker.process.pid + "\n";
      };
      if (typeof this.options.describeWorker === 'function') {
        workersArray = (function() {
          var _ref, _results;
          _ref = cluster.workers;
          _results = [];
          for (id in _ref) {
            worker = _ref[id];
            _results.push(worker);
          }
          return _results;
        })();
        return async.map(workersArray, function(worker, cb) {
          return _this.options.describeWorker(worker, function(description) {
            var str;
            str = "" + (formatTitle(worker.id, worker)) + (terminal.lpad(description, 1));
            return cb(null, str);
          });
        }, function(err, results) {
          return callback(results.join("\n"));
        });
      } else {
        return callback(((function() {
          var _ref, _results;
          _ref = cluster.workers;
          _results = [];
          for (id in _ref) {
            worker = _ref[id];
            _results.push(formatTitle(id, worker));
          }
          return _results;
        })()).join("\n"));
      }
    };

    return ReplrServer;

  })(EventEmitter);

  module.exports = ReplrServer;

}).call(this);