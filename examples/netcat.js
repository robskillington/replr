var chalk = require('chalk');
var replr = require('../lib/');

var statefulThing = {
    counter: 1
};

var options = {
    mode: 'tcp',
    port: 2323,
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

var replrServer = replr.create(options);
console.log('Now open REPL with: nc localhost 2323');
