var chalk = require('chalk');
var replr = require('../lib/');

var statefulThing = {
    counter: 1
};

var options = {
    mode: 'http',
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
console.log('Now open REPL with: node bin/replr.js localhost 2323');
