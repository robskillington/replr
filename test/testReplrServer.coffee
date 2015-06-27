cluster = require('cluster')
net = require('net')
replr = require('../src/')
ReplrServer = require('../src/ReplrServer')
test = require('tape')
findPort = require('find-port')
CountedReady = require('ready-signal/counted')

return replr.configureAsWorker() if cluster.isWorker

test 'Server starts and performs simple math', (assert)->
  startServerAndEvaluate '4 + 5', (result)->
    assert.equal result, '9', '4 + 5 = 9'
    assert.end()

test 'Server lists commands with cmds()', (assert)->
  startServerAndEvaluate 'cmds()', (result, server, client)->
    methods = []
    for key, value of client.repl.context.exported
      methods.push key if typeof value == 'function'

    for method in methods
      assert.notEqual result.indexOf("#{method}("), -1, "documents command #{method}"

    assert.end()

test 'Server lists vars with vars()', (assert)->
  startServerAndEvaluate 'vars()', (result, server, client)->
    vars = []
    for key, value of client.repl.context.exported
      vars.push key if typeof value != 'function'

    for variable in vars
      assert.notEqual result.indexOf("#{variable} "), -1, "lists var #{variable}"

    assert.end()

test 'Server lists workers with workers()', (assert)->
  worker = cluster.fork()
  startServerAndEvaluate 'workers()', (result, server, client)->
    desc = "[1] id=1, pid=#{worker.process.pid}"
    assert.notEqual result.indexOf(desc), -1, "displays worker description: #{desc}"
    worker.kill()
    assert.end()

test 'Server can write back an exported write call', (assert)->
  startServerAndEvaluate 'write(\'testing 1,2,3\')', (result, server, client)->
    assert.equal result.trim(), 'testing 1,2,3', 'writes back \'testing 1,2,3\''
    assert.end()

test 'Two replrs can listen in one process', (assert)->
  findPort 8000, 8020, (ports) ->
    one = new ReplrServer({port: ports[0], mode: 'tcp'})
    two = new ReplrServer({port: ports[1], mode: 'tcp'})

    ready = CountedReady 2

    one.once 'listening', ready.signal
    two.once 'listening', ready.signal

    ready ->
      one.close()
      two.close()
      assert.end()


# TODO: fix this one
# test 'Server supports REPL on worker', (assert)->
#   worker = cluster.fork()
#   startServerAndEvaluateOnWorker worker.id, '4 + 5', (result)->
#     assert.equal result, '9', '4 + 5 = 9'
#     worker.kill()
#     assert.end()

startServerAndConnect = (callback)->
  server = new ReplrServer({mode: 'tcp', useGlobal: true, ignoreUndefined: true})
  server.on 'listening', ()->
    sock = new net.Socket()
    sock.setEncoding 'utf8'
    sock.on 'error', (err)-> console.log 'err:', err
    sock.connect server.options.port, 'localhost', ()->
      callback {server: server, sock: sock}

startServerAndEvaluate = (expr, callback)->
  startServerAndConnect (serverAndSocket)->
    {server, sock} = serverAndSocket

    result = ''
    evaluatingResult = false
    sock.on 'data', (data)->
      isPrompt = data.indexOf(server.options.prompt) != -1

      if isPrompt && !evaluatingResult
        evaluatingResult = true

      else if isPrompt && evaluatingResult
        evaluatingResult = false
        if data.length > server.options.prompt.length
          result += data.substr 0, data.indexOf(server.options.prompt)
        result = result.slice(0, -1) if result[result.length-1] == '\n'
        client = server.clients[0]
        sock.end()
        server.close()
        callback result, server, client

      else if evaluatingResult
        result += data

    sock.write "#{expr}\r"


startServerAndEvaluateOnWorker = (workerIndex, expr, callback)->
  startServerAndConnect (serverAndSocket)->
    {server, sock} = serverAndSocket

    result = ''
    evaluatingResult = false
    selectedWorker = false
    sock.on 'data', (data)->
      isPrompt = data.indexOf(server.options.prompt) != -1

      if !selectedWorker && data.indexOf(server.options.prompt) != -1
        selectedWorker = true
        sock.write "select(#{workerIndex})\r\n"

      else if selectedWorker && data.indexOf('Welcome') != -1
        evaluatingResult = true
        sock.write "#{expr}\r\n"

      else if isPrompt && evaluatingResult
        evaluatingResult = false
        if data.length > server.options.prompt.length
          result += data.substr 0, data.indexOf(server.options.prompt)
        result = result.slice(0, -1) if result[result.length-1] == '\n'
        client = server.clients[0]
        sock.end()
        server.close()
        callback result, server, client

      else if evaluatingResult
        result += data
