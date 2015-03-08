var replr = require('../lib/');

var statefulThing = {
    counter: 1
};

var options = {
    name: 'MyApp console',
    prompt: 'myApp> '.grey,
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
console.log('Now open REPL with `nc localhost 2323` or equivalent');
