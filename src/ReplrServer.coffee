net = require('net')
http = require('http')
extend = require('xtend')
cluster = require('cluster')
chalk = require('chalk')
terminal = require('terminal')
async = require('async')
EventEmitter = require('events').EventEmitter
MemoryStream = require('memorystream')
portscanner = require('portscanner')
ReplrClient = require('./ReplrClient')
ReplrEvents = require('./ReplrEvents')
Util = require('./Util')

class ReplrServer extends EventEmitter

  @::OPTIONS_DEFAULT =
    name: 'Replr'
    port: 2323
    mode: 'http'
    prompt: chalk.gray('replr> ')
    terminal: false
    useColors: false
    describeWorker: null

  @::OPTIONS_MODES = ['http', 'tcp', 'unixdomainsocket', 'raw', 'noserver']

  @::OPTIONS_REPL_KEYS = ['port', 'prompt', 'terminal', 'useColors', 'useGlobal', 'ignoreUndefined']

  constructor: (options, start=true)->
    options = options || {}
    if options.port
      if typeof options.port == 'number'
        throw new Error('bad port') if !Util::isInt(options.port) || options.port < 1
      else if typeof options.port != 'string'
        throw new Error('bad port')
    if options.prompt
      throw new Error('bad prompt') if typeof options.prompt != 'string'
    if options.mode
      throw new Error('bad mode') if @OPTIONS_MODES.indexOf(options.mode) == -1
    #todo: validate other options

    @options = extend @OPTIONS_DEFAULT, options
    @clients = []
    @started = false
    @starting = false
    return if start then @start() else @


  start: (callback)->
    ready = ()=>
      @started = true
      @starting = false
      @emit 'listening'

    return if @starting
    @starting = true

    return ready() if @options.mode == 'noserver' || @options.port == false

    onVerified = (err, status)=>
      if err || status == 'open'
        callback(err || new Error('Port already taken')) if callback
        return

      mode = @options.mode
      if mode == 'tcp' || mode == 'unixdomainsocket' || mode == 'raw'
        @socketServer = net.createServer @open.bind(@)
      else
        @socketServer = http.createServer ()=> # No-op
        @socketServer.on 'upgrade', (req, socket, head)=>
          try
            str = head.toString('utf8')
            if req.headers && req.headers.upgrade == 'replr'
              @open socket
            else
              socket.end()
          catch exc
            socket.end()

      @socketServer.on 'listening', ()=>
        ready()

      onError = (err)=>
        callback err if callback

      @socketServer.once 'error', onError

      try
        @socketServer.listen @options.port
      catch err
        @started = false
        @starting = false
        callback err if callback

      @socketServer.removeListener 'error', onError

    if @options.port == 0
      onVerified null, 'free'
    else if typeof @options.port == 'number'
      portscanner.checkPortStatus @options.port, '127.0.0.1', onVerified
    else
      onVerified null, 'free'


  close: (callback)->
    if @starting
      @once 'listening', ()=>
        @close callback
    else if @started
      @socketServer.close ()=>
        @started = false
        @emit 'close'
        callback() if callback
    else
      callback(new Error('Already closed')) if callback


  open: (socket, overriddenOptions={})->
    # Start session with options
    replOptions = {}
    for key in @OPTIONS_REPL_KEYS
      replOptions[key] = @options[key] if @options.hasOwnProperty key

    clientOptions = extend(overriddenOptions, @options)

    client = new ReplrClient(@, socket, clientOptions, replOptions)

    @clients.push client

    # Track client and remove when disconnect occurs
    socket.on 'end', ()=>
      @clients.splice @clients.indexOf(client), 1

    socket.on 'error', (err)=>
      return if err && err.code == 'EPIPE'
      # Let the socket close up

    # Setup context variables from default exports and options
    client.repl.context.exported = {}
    for key, value of client.exports()
      client.repl.context.exported[key] = value
      client.repl.context[key] = value

    if @options.exports && typeof @options.exports == 'function'
      exports = @options.exports(client)
      if exports && Object.keys(exports).length > 0
        for key, value of exports
          # Bind exports to the context to call other methods and "write" with ease
          if typeof value == 'function'
            originalValue = value
            value = value.bind client.repl.context
            value.unbound = originalValue

          client.repl.context.exported[key] = value
          client.repl.context[key] = value

    # Welcome client
    client.welcome()

    return client


  forwardToWorker: (client, worker)->
    msg =
      type: ReplrEvents::WORKER_RECEIVE
      options: @options

    # Keep the REPL alive but attached to dummy so we
    # only remove the client after connection closes
    dummy = new MemoryStream()
    client.repl.inputStream = dummy
    client.repl.outputStream = dummy
    client.repl.rli.input = dummy
    client.repl.rli.output = dummy

    worker.send msg, client.socket


  describeWorkers: (callback)->
    formatTitle = (id, worker)-> "[#{id}] id=#{id}, pid=#{worker.process.pid}\n"

    if typeof @options.describeWorker == 'function'
      workersArray = (worker for id, worker of cluster.workers)

      async.map workersArray, (worker, cb)=>
        @options.describeWorker worker, (description)=>
          str = "#{formatTitle(worker.id, worker)}#{terminal.lpad(description, 1)}"
          cb null, str
      , (err, results)=>
        callback results.join("\n")

    else
      callback (formatTitle(id, worker) for id, worker of cluster.workers).join("\n")


module.exports = ReplrServer
