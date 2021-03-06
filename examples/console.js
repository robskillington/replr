var chalk = require('chalk');
var duplexer = require('duplexer');
var keypress = require('keypress');
var replr = require('../lib/');
var startReplrClient = require('../bin/replr');

var statefulThing = {
    counter: 1
};

var options = {
    name: 'MyApp console',
    prompt: chalk.gray('myApp> '),
    useColors: true,
    useGlobal: true,
    ignoreUndefined: true,
    exports: function replrExports() {
        return {
            increment: function increment() {
                return statefulThing.counter++;
            },
            getStatefulThing: function getStatefulThing() {
                return statefulThing;
            }
        };
    }
};

replr.create(options);
startReplrClient();
