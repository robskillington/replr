async = require('async')
repl = require('repl')
cluster = require('cluster')
chalk = require('chalk')
doc = require('doc')
terminal = require('terminal')
util = require('util')
Transform = require('stream').Transform

class ReplrClient

  @::TERM_CODES = 
    clear: '\u001B[2J'
    clearToEndOfLine: '\u001b[K'
    zeroPos: '\u001B[0;0f'
    moveLeft: '\u001b[D'
    moveRight: '\u001b[C'
    moveUp: '\u001b[A'
    moveDown: '\u001b[B'
    saveCursor: '\u001b7'
    restoreCursor: '\u001b8'

  @::TERM_CODES_VALUES = []
  for key, value of @::TERM_CODES
    @::TERM_CODES_VALUES.push value

  constructor: (@server, @socket, @options, replOptions)->
    @width = @options.width || 80
    @height = @options.height || 40

    replOptions.input = new InputInterceptor({
      client: @,
      socket: socket
    })
    replOptions.output = socket

    @repl = repl.start replOptions

    # Ensure we close the socket if repl is closed
    @repl.on 'exit', ()=>
      @socket.end()


  resize: (width, height)->
    if typeof width == 'number' && typeof height == 'number'
      @width = width
      @height = height


  write: (msg, callback=null)->
    if !@options.terminal
      msg = terminal.stripStyles msg
      for value in @TERM_CODES_VALUES
        try
          msg = msg.replace new RegExp(value, 'g'), ''
        catch err
          # Noop, some versions of node does not support unicode literals

    if !@options.useColors
      msg = chalk.stripColor msg

    if callback
      @socket.write msg, callback
    else
      @socket.write msg


  send: (result, callback=null)->
    @write "\n#{@indent(result, 2)}\n\n", callback
    return


  indent: (str, indentBy)->
    spaces = ''
    for i in [1..indentBy]
      spaces += ' '
    return "#{spaces}#{str.replace(/\n/g, "\n" + spaces)}"


  exports: ()->
    cmds = ()=> 
      doc: "Prints all available commands in the local REPL context with documentation"
      @send @getCommands()

    vars = ()=>
      doc: "Prints all available variables in the local REPL context and their types"
      @send @getVars()

    workers = ()=>
      doc: "Prints all workers running on this cluster"
      prompt = @repl.prompt
      @repl.prompt = ''
      @getWorkersDescription (description)=>
        @send description
        @write prompt
        @repl.prompt = prompt
      return

    select = (workerId)=>
      doc: "Changes into the worker context with the given workerId"
      @changeWorker workerId

    write = (obj, options={colors: true})=>
      doc: "Writes text or util.inspect(obj, text) to this REPL session, useful for other exported methods"
      text = if typeof obj == 'string' then obj else util.inspect obj, options
      @send text
      return

    exports = 
      help: 'Type .help for repl help, use cmds() to get commands in current context'
      exit: 'Did you mean .exit?'
      repl: @repl
      replOptions: @options
      cmds: cmds
      vars: vars
      write: write

    if cluster.isMaster
      exports.workers = workers 
      exports.select = select

    return exports


  changeWorker: (workerId)->
    for key, worker of cluster.workers
      if worker.id == workerId
        @server.forwardToWorker @, worker
        return

    @send "Could not find worker with worker ID '#{workerId}'"


  getCommands: ()->
    exported = {}
    for key, value of @repl.context.exported
      # Use the unbound version of the method for unwrapping documentation if available
      exported[key] = if typeof value.unbound == 'function' then value.unbound else value
    commands = (key for key in Object.keys(exported) when typeof exported[key] == 'function')

    signatureAsString = (name, func)-> "#{key}(#{doc.docArgsAsArray(func).join(', ')})"

    longest = 0
    for key in commands
      signature = signatureAsString(key, exported[key])
      longest = signature.length if signature.length > longest

    indentBy = longest + 6

    descriptions = []
    for key in commands
      func = exported[key]
      signature = terminal.rpad signatureAsString(key, func), indentBy
      described = ''
      terminal.printWrapped doc.docAsString(func), @options.width, indentBy, (out)->
        described += out + "\n"

      descriptions.push "#{signature}#{described.substring(indentBy)}"

    if descriptions.length > 0
      descriptions.unshift ''
      descriptions.unshift "#{terminal.rpad('--', indentBy)}--"
      descriptions.unshift "#{terminal.rpad('function', indentBy)}documentation"
      descriptions.unshift ''
      descriptions.unshift chalk.cyan("(#{commands.length}) commands in the local REPL context")
    else
      descriptions = [chalk.cyan("There are no commands in the local REPL context")]

    return descriptions.join "\n"


  getVars: ()->
    exported = @repl.context.exported
    vars = (key for key in Object.keys(exported) when typeof exported[key] != 'function')

    longest = 0
    for key in vars
      longest = key.length if key.length > longest

    indentBy = longest + 6

    descriptions = []
    for key in vars
      value = exported[key]
      formattedKey = terminal.rpad key, indentBy
      descriptions.push "#{formattedKey}#{typeof value}"

    if descriptions.length > 0
      descriptions.unshift ''
      descriptions.unshift "#{terminal.rpad('--', indentBy)}--"
      descriptions.unshift "#{terminal.rpad('name', indentBy)}info"
      descriptions.unshift ''
      descriptions.unshift chalk.cyan("(#{vars.length}) variables in the local REPL context")
    else
      descriptions = [chalk.cyan("There are no variables in the local REPL context")]

    return descriptions.join "\n"


  getWorkersDescription: (callback)->
    @server.describeWorkers (description)=>
      active = Object.keys(cluster.workers).length
      plural = if active != 1 then 's' else ''
      nonEssentialLineBreak = if active > 0 then "\n" else ''

      callback """
               #{chalk.cyan("(#{active}) worker active#{plural}#{nonEssentialLineBreak}")}
               #{description}
               """


  welcome: ()->
    @getWelcomeMessage (message)=>
      @write [@TERM_CODES.clear, @TERM_CODES.zeroPos, message].join ''


  getWelcomeMessage: (callback)->
    title = chalk.cyan.bold('Welcome')
    hint = 'Hint: use cmds() to print the current exports available to you'

    if cluster.isMaster
      @getWorkersDescription (description)=>
        callback  """
                  #{title} #{@options.name}[cluster.Master]

                  #{@indent(description, 2)}

                  #{hint}

                  #{@repl.prompt}
                  """
    else 
      callback  """
                #{title} to #{@options.name}[cluster.Worker]

                #{hint}

                #{@repl.prompt}
                """


  getTabCompletions: (input, callback)->
    @repl.complete input, (err, results)=>
      if !err
        completions = results[0]

        longest = 0
        for key in completions
          longest = key.length if key.length > longest

        columns = Math.floor(@width/longest)
        rows = Math.ceil(completions.length/columns)

        remaining = completions.concat().sort()
        columnsText = []
        while columnsText.length < columns
          columnsText.push remaining.splice(0, rows)

        text = ''
        padding = 2
        for i in [0...rows]
          for j in [0...columns]
            if columnsText[j][i]
              text += terminal.rpad columnsText[j][i], longest+padding
          text += '\n'

        callback text, completions
      else
        callback '', []


class InputInterceptor extends Transform
  @::MAX_PAST_ENTRIES = 64

  constructor: (options)->
    super(options)
    @client = options.client
    @socket = options.socket
    @socket.pipe @
    @inputBuffer = ''
    @pastEntries = []
    @inputCursor = 0


  resume: ()->
    @socket.resume()


  _transform: (chunk, encoding, callback)->
    input = ''
    try
      input = chunk.toString('utf8')
    catch exc
      @push chunk
      return callback()

    async.each [0...input.length], (i, nextCallback)=>
      charCode = input[i].charCodeAt 0
      @_transformSingleInput input[i], charCode, nextCallback
    , callback


  _transformSingleInput: (input, charCode, callback)->
    if input == '\t'
      @client.getTabCompletions @inputBuffer, (text, completions)=>
        if completions.length == 1
          # Complete for user
          remaining = completions[0].substr @inputBuffer.length
          @inputBuffer += remaining
          @client.write remaining
          callback()
        else
          # List completions
          @client.write "\n#{text}#{@client.repl.prompt}#{@inputBuffer}"
          callback()

    else if input == '\n' || input == '\r'
      # Endline, push read buffer and return
      @push @inputBuffer
      @pastEntries.push @inputBuffer
      @pastEntries = @pastEntries.slice 1 if @pastEntries.length > @MAX_PAST_ENTRIES
      @inputBuffer = ''
      @inputCursor = 0
      @push input
      callback()

    else if charCode == 127
      # Backspace
      if @inputBuffer.length > 0
        @inputBuffer = @inputBuffer.slice 0, -1
        @client.write ReplrClient::TERM_CODES.moveLeft
        @client.write ReplrClient::TERM_CODES.clearToEndOfLine
        @inputCursor--
      callback()

    #todo: 
    # - add move left, right
    # - add multiline support
    # - allow up/down nav of past entries

    else
      # Anything else add to the buffer
      if (charCode > 31 && charCode < 127) || charCode > 160
        @inputCursor++
        @inputBuffer += input
      callback()


module.exports = ReplrClient
