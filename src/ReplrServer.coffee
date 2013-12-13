repl = require('repl')
net = require('net')
merge = require('merge')
cluster = require('cluster')
colors = require('colors')
terminal = require('terminal')
MemoryStream = require('memorystream')
ReplrClient = require('./ReplrClient')
ReplrEvents = require('./ReplrEvents')
Util = require('./Util')

class ReplrServer

  @::OPTIONS_DEFAULT = 
    name: 'Replr'
    port: 2323
    prompt: 'replr> '.grey
    terminal: false
    useColors: false
    describeWorker: null

  @::OPTIONS_REPL_KEYS = ['port', 'prompt', 'terminal', 'useColors']

  constructor: (options, start=true)->
    if options 
      if options.port
        throw new Error('bad port') if !Util::isInt(options.port) || options.port < 1
      if options.prompt
        throw new Error('bad prompt') if typeof options.prompt != 'string'
      #todo: validate other options

    @options = merge @OPTIONS_DEFAULT, options
    @clients = []
    return if start then @start() else @


  start: ()->
    @socketServer = net.createServer @open.bind(@)
    @socketServer.listen @options.port
    return @


  open: (socket)->
    # Start session with options
    replOptions = {}
    for key in @OPTIONS_REPL_KEYS
      replOptions[key] = @options[key] if @options.hasOwnProperty key
    replOptions.input = socket
    replOptions.output = socket

    r = repl.start replOptions

    # Ensure we close the socket if repl is closed
    r.on 'exit', ()=>
      socket.end()

    # Track client and remove when disconnect occurs
    client = new ReplrClient(@, @options, socket, r)
    @clients.push client
    socket.on 'end', ()=>
      @clients.splice @clients.indexOf(client), 1

    # Setup context variables from default exports and options
    r.context.exported = {}
    for key, value of client.exports()
      r.context.exported[key] = value
      r.context[key] = value

    if @options.exports && typeof @options.exports == 'function'
      exports = @options.exports(client)
      if exports && Object.keys(exports).length > 0 
        for key, value of exports
          r.context.exported[key] = value
          r.context[key] = value

    # Welcome client
    client.welcome()


  forwardToWorker: (client, worker)->
    msg = 
      type: ReplrEvents::WORKER_RECEIVE
      options: @options

    # Keep the REPL alive but attached to dummy so we remove client after connection closes
    dummy = new MemoryStream()
    client.repl.inputStream = dummy
    client.repl.outputStream = dummy
    client.repl.rli.input = dummy
    client.repl.rli.output = dummy

    worker.send msg, client.socket


  describeWorkers: ()->
    descriptions = []
    for id, worker of cluster.workers
      description = "[#{id}] id=#{id}, pid=#{worker.process.pid}\n"
      if typeof @options.describeWorker == 'function'
        custom = @options.describeWorker worker
        description += terminal.lpad(custom, 1)
      descriptions.push description

    return descriptions.join "\n"


module.exports = ReplrServer
