# replr

REPL remote access for Node apps/services with cluster and worker selection support.

### Features

- [x] Remote access over replr client with HTTP upgrade, netcat or telnet on a TCP port
- [x] Use as console to spin up a rails console clone for your stack in minutes
- [x] Use `cmds()` to list all exported methods and corresponding documentation
- [x] Use `vars()` to list all exported vars
- [x] Use `workers()` to describe all workers of a cluster node app
- [x] Use `select(workerId)` to switch REPL context to a worker
- [x] Supports REPL over unix domain socket by specifying `port` as a file path

### How add replr?

```js
replr.create({
    name: 'MyApp console',
    prompt: 'myApp> ',
    port: 2323,
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
});
```

For an example of using replr as a console see the `examples/console.js` example.

## Installation

`npm install replr`

## Tests

`npm test`

## MIT Licensed

