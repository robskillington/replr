// Generated by CoffeeScript 1.6.3
(function() {
  var InputInterceptor, ReplrClient, Transform, async, chalk, cluster, doc, repl, terminal, util,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  async = require('async');

  repl = require('repl');

  cluster = require('cluster');

  chalk = require('chalk');

  doc = require('doc');

  terminal = require('terminal');

  util = require('util');

  Transform = require('stream').Transform;

  ReplrClient = (function() {
    var key, value, _ref;

    ReplrClient.prototype.TERM_CODES = {
      clear: '\u001B[2J',
      clearToEndOfLine: '\u001b[K',
      zeroPos: '\u001B[0;0f',
      moveLeft: '\u001b[D',
      moveRight: '\u001b[C',
      moveUp: '\u001b[A',
      moveDown: '\u001b[B',
      saveCursor: '\u001b7',
      restoreCursor: '\u001b8'
    };

    ReplrClient.prototype.TERM_CODES_VALUES = [];

    _ref = ReplrClient.prototype.TERM_CODES;
    for (key in _ref) {
      value = _ref[key];
      ReplrClient.prototype.TERM_CODES_VALUES.push(value);
    }

    function ReplrClient(server, socket, options, replOptions) {
      var _this = this;
      this.server = server;
      this.socket = socket;
      this.options = options;
      this.width = this.options.width || 80;
      this.height = this.options.height || 40;
      replOptions.input = new InputInterceptor({
        client: this,
        socket: socket
      });
      replOptions.output = socket;
      this.repl = repl.start(replOptions);
      this.repl.on('exit', function() {
        return _this.socket.end();
      });
    }

    ReplrClient.prototype.resize = function(width, height) {
      if (typeof width === 'number' && typeof height === 'number') {
        this.width = width;
        return this.height = height;
      }
    };

    ReplrClient.prototype.write = function(msg, callback) {
      var err, _i, _len, _ref1;
      if (callback == null) {
        callback = null;
      }
      if (!this.options.terminal) {
        msg = terminal.stripStyles(msg);
        _ref1 = this.TERM_CODES_VALUES;
        for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
          value = _ref1[_i];
          try {
            msg = msg.replace(new RegExp(value, 'g'), '');
          } catch (_error) {
            err = _error;
          }
        }
      }
      if (!this.options.useColors) {
        msg = chalk.stripColor(msg);
      }
      if (callback) {
        return this.socket.write(msg, callback);
      } else {
        return this.socket.write(msg);
      }
    };

    ReplrClient.prototype.send = function(result, callback) {
      if (callback == null) {
        callback = null;
      }
      this.write("\n" + (this.indent(result, 2)) + "\n\n", callback);
    };

    ReplrClient.prototype.indent = function(str, indentBy) {
      var i, spaces, _i;
      spaces = '';
      for (i = _i = 1; 1 <= indentBy ? _i <= indentBy : _i >= indentBy; i = 1 <= indentBy ? ++_i : --_i) {
        spaces += ' ';
      }
      return "" + spaces + (str.replace(/\n/g, "\n" + spaces));
    };

    ReplrClient.prototype.exports = function() {
      var cmds, exports, select, vars, workers, write,
        _this = this;
      cmds = function() {
        ({
          doc: "Prints all available commands in the local REPL context with documentation"
        });
        return _this.send(_this.getCommands());
      };
      vars = function() {
        ({
          doc: "Prints all available variables in the local REPL context and their types"
        });
        return _this.send(_this.getVars());
      };
      workers = function() {
        var prompt;
        ({
          doc: "Prints all workers running on this cluster"
        });
        prompt = _this.repl.prompt;
        _this.repl.prompt = '';
        _this.getWorkersDescription(function(description) {
          _this.send(description);
          _this.write(prompt);
          return _this.repl.prompt = prompt;
        });
      };
      select = function(workerId) {
        ({
          doc: "Changes into the worker context with the given workerId"
        });
        return _this.changeWorker(workerId);
      };
      write = function(obj, options) {
        var text;
        if (options == null) {
          options = {
            colors: true
          };
        }
        ({
          doc: "Writes text or util.inspect(obj, text) to this REPL session, useful for other exported methods"
        });
        text = typeof obj === 'string' ? obj : util.inspect(obj, options);
        _this.send(text);
      };
      exports = {
        help: 'Type .help for repl help, use cmds() to get commands in current context',
        exit: 'Did you mean .exit?',
        repl: this.repl,
        replOptions: this.options,
        cmds: cmds,
        vars: vars,
        write: write
      };
      if (cluster.isMaster) {
        exports.workers = workers;
        exports.select = select;
      }
      return exports;
    };

    ReplrClient.prototype.changeWorker = function(workerId) {
      var worker, _ref1;
      _ref1 = cluster.workers;
      for (key in _ref1) {
        worker = _ref1[key];
        if (worker.id === workerId) {
          this.server.forwardToWorker(this, worker);
          return;
        }
      }
      return this.send("Could not find worker with worker ID '" + workerId + "'");
    };

    ReplrClient.prototype.getCommands = function() {
      var commands, described, descriptions, exported, func, indentBy, longest, signature, signatureAsString, _i, _j, _len, _len1, _ref1;
      exported = {};
      _ref1 = this.repl.context.exported;
      for (key in _ref1) {
        value = _ref1[key];
        exported[key] = typeof value.unbound === 'function' ? value.unbound : value;
      }
      commands = (function() {
        var _i, _len, _ref2, _results;
        _ref2 = Object.keys(exported);
        _results = [];
        for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
          key = _ref2[_i];
          if (typeof exported[key] === 'function') {
            _results.push(key);
          }
        }
        return _results;
      })();
      signatureAsString = function(name, func) {
        return "" + key + "(" + (doc.docArgsAsArray(func).join(', ')) + ")";
      };
      longest = 0;
      for (_i = 0, _len = commands.length; _i < _len; _i++) {
        key = commands[_i];
        signature = signatureAsString(key, exported[key]);
        if (signature.length > longest) {
          longest = signature.length;
        }
      }
      indentBy = longest + 6;
      descriptions = [];
      for (_j = 0, _len1 = commands.length; _j < _len1; _j++) {
        key = commands[_j];
        func = exported[key];
        signature = terminal.rpad(signatureAsString(key, func), indentBy);
        described = '';
        terminal.printWrapped(doc.docAsString(func), this.options.width, indentBy, function(out) {
          return described += out + "\n";
        });
        descriptions.push("" + signature + (described.substring(indentBy)));
      }
      if (descriptions.length > 0) {
        descriptions.unshift('');
        descriptions.unshift("" + (terminal.rpad('--', indentBy)) + "--");
        descriptions.unshift("" + (terminal.rpad('function', indentBy)) + "documentation");
        descriptions.unshift('');
        descriptions.unshift(chalk.cyan("(" + commands.length + ") commands in the local REPL context"));
      } else {
        descriptions = [chalk.cyan("There are no commands in the local REPL context")];
      }
      return descriptions.join("\n");
    };

    ReplrClient.prototype.getVars = function() {
      var descriptions, exported, formattedKey, indentBy, longest, vars, _i, _j, _len, _len1;
      exported = this.repl.context.exported;
      vars = (function() {
        var _i, _len, _ref1, _results;
        _ref1 = Object.keys(exported);
        _results = [];
        for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
          key = _ref1[_i];
          if (typeof exported[key] !== 'function') {
            _results.push(key);
          }
        }
        return _results;
      })();
      longest = 0;
      for (_i = 0, _len = vars.length; _i < _len; _i++) {
        key = vars[_i];
        if (key.length > longest) {
          longest = key.length;
        }
      }
      indentBy = longest + 6;
      descriptions = [];
      for (_j = 0, _len1 = vars.length; _j < _len1; _j++) {
        key = vars[_j];
        value = exported[key];
        formattedKey = terminal.rpad(key, indentBy);
        descriptions.push("" + formattedKey + (typeof value));
      }
      if (descriptions.length > 0) {
        descriptions.unshift('');
        descriptions.unshift("" + (terminal.rpad('--', indentBy)) + "--");
        descriptions.unshift("" + (terminal.rpad('name', indentBy)) + "info");
        descriptions.unshift('');
        descriptions.unshift(chalk.cyan("(" + vars.length + ") variables in the local REPL context"));
      } else {
        descriptions = [chalk.cyan("There are no variables in the local REPL context")];
      }
      return descriptions.join("\n");
    };

    ReplrClient.prototype.getWorkersDescription = function(callback) {
      var _this = this;
      return this.server.describeWorkers(function(description) {
        var active, nonEssentialLineBreak, plural;
        active = Object.keys(cluster.workers).length;
        plural = active !== 1 ? 's' : '';
        nonEssentialLineBreak = active > 0 ? "\n" : '';
        return callback("" + (chalk.cyan("(" + active + ") worker active" + plural + nonEssentialLineBreak)) + "\n" + description);
      });
    };

    ReplrClient.prototype.welcome = function() {
      var _this = this;
      return this.getWelcomeMessage(function(message) {
        return _this.write([_this.TERM_CODES.clear, _this.TERM_CODES.zeroPos, message].join(''));
      });
    };

    ReplrClient.prototype.getWelcomeMessage = function(callback) {
      var hint, title,
        _this = this;
      title = chalk.cyan.bold('Welcome');
      hint = 'Hint: use cmds() to print the current exports available to you';
      if (cluster.isMaster) {
        return this.getWorkersDescription(function(description) {
          return callback("" + title + " " + _this.options.name + "[cluster.Master]\n\n" + (_this.indent(description, 2)) + "\n\n" + hint + "\n\n" + _this.repl.prompt);
        });
      } else {
        return callback("" + title + " to " + this.options.name + "[cluster.Worker]\n\n" + hint + "\n\n" + this.repl.prompt);
      }
    };

    ReplrClient.prototype.getTabCompletions = function(input, callback) {
      var _this = this;
      return this.repl.complete(input, function(err, results) {
        var columns, columnsText, completions, i, j, longest, padding, remaining, rows, text, _i, _j, _k, _len;
        if (!err) {
          completions = results[0];
          longest = 0;
          for (_i = 0, _len = completions.length; _i < _len; _i++) {
            key = completions[_i];
            if (key.length > longest) {
              longest = key.length;
            }
          }
          columns = Math.floor(_this.width / longest);
          rows = Math.ceil(completions.length / columns);
          remaining = completions.concat().sort();
          columnsText = [];
          while (columnsText.length < columns) {
            columnsText.push(remaining.splice(0, rows));
          }
          text = '';
          padding = 2;
          for (i = _j = 0; 0 <= rows ? _j < rows : _j > rows; i = 0 <= rows ? ++_j : --_j) {
            for (j = _k = 0; 0 <= columns ? _k < columns : _k > columns; j = 0 <= columns ? ++_k : --_k) {
              if (columnsText[j][i]) {
                text += terminal.rpad(columnsText[j][i], longest + padding);
              }
            }
            text += '\n';
          }
          return callback(text, completions);
        } else {
          return callback('', []);
        }
      });
    };

    return ReplrClient;

  })();

  InputInterceptor = (function(_super) {
    __extends(InputInterceptor, _super);

    InputInterceptor.prototype.MAX_PAST_ENTRIES = 64;

    function InputInterceptor(options) {
      InputInterceptor.__super__.constructor.call(this, options);
      this.client = options.client;
      this.socket = options.socket;
      this.socket.pipe(this);
      this.inputBuffer = '';
      this.pastEntries = [];
      this.inputCursor = 0;
    }

    InputInterceptor.prototype.resume = function() {
      return this.socket.resume();
    };

    InputInterceptor.prototype._transform = function(chunk, encoding, callback) {
      var exc, input, _i, _ref, _results,
        _this = this;
      input = '';
      try {
        input = chunk.toString('utf8');
      } catch (_error) {
        exc = _error;
        this.push(chunk);
        return callback();
      }
      return async.each((function() {
        _results = [];
        for (var _i = 0, _ref = input.length; 0 <= _ref ? _i < _ref : _i > _ref; 0 <= _ref ? _i++ : _i--){ _results.push(_i); }
        return _results;
      }).apply(this), function(i, nextCallback) {
        var charCode;
        charCode = input[i].charCodeAt(0);
        return _this._transformSingleInput(input[i], charCode, nextCallback);
      }, callback);
    };

    InputInterceptor.prototype._transformSingleInput = function(input, charCode, callback) {
      var _this = this;
      if (input === '\t') {
        return this.client.getTabCompletions(this.inputBuffer, function(text, completions) {
          var remaining;
          if (completions.length === 1) {
            remaining = completions[0].substr(_this.inputBuffer.length);
            _this.inputBuffer += remaining;
            _this.client.write(remaining);
            return callback();
          } else {
            _this.client.write("\n" + text + _this.client.repl.prompt + _this.inputBuffer);
            return callback();
          }
        });
      } else if (input === '\n' || input === '\r') {
        this.push(this.inputBuffer);
        this.pastEntries.push(this.inputBuffer);
        if (this.pastEntries.length > this.MAX_PAST_ENTRIES) {
          this.pastEntries = this.pastEntries.slice(1);
        }
        this.inputBuffer = '';
        this.inputCursor = 0;
        this.push(input);
        return callback();
      } else if (charCode === 127) {
        if (this.inputBuffer.length > 0) {
          this.inputBuffer = this.inputBuffer.slice(0, -1);
          this.client.write(ReplrClient.prototype.TERM_CODES.moveLeft);
          this.client.write(ReplrClient.prototype.TERM_CODES.clearToEndOfLine);
          this.inputCursor--;
        }
        return callback();
      } else {
        if ((charCode > 31 && charCode < 127) || charCode > 160) {
          this.inputCursor++;
          this.inputBuffer += input;
        }
        return callback();
      }
    };

    return InputInterceptor;

  })(Transform);

  module.exports = ReplrClient;

}).call(this);
