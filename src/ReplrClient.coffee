cluster = require('cluster')
colors = require('colors')
doc = require('doc')
terminal = require('terminal')

class ReplrClient

  @::TERM_CODES = 
    clear: '\u001B[2J'
    zeroPos: '\u001B[0;0f'

  @::TERM_CODES_VALUES = []
  for key, value of @::TERM_CODES
    @::TERM_CODES_VALUES.push value

  constructor: (@server, @options, @socket, @repl)->
    # Sets properties


  write: (msg, callback=null)->
    if !@options.terminal
      msg = terminal.stripStyles(msg)
      for value in @TERM_CODES_VALUES
        msg = msg.replace new RegExp(value, 'g'), ''

    if !@options.useColors
      msg = msg.stripColors()

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
    "#{spaces}#{str.replace(/\n/g, "\n" + spaces)}"


  exports: ()->
    cmds = ()=> 
      doc: "Prints all available commands in the local REPL context with documentation"
      @send @getCommands()

    vars = ()=>
      doc: "Prints all available variables in the local REPL context and their types"
      @send @getVars()

    workers = ()=>
      doc: "Prints all workers running on this cluster"
      @send @getWorkers()

    cw = (workerId)=>
      doc: "Changes into the worker context with the given workerId"
      @changeWorker workerId

    exports = 
      help: 'Type .help for repl help, use cmds() to get commands in current context'
      exit: 'Did you mean .exit?'
      repl: @repl
      replOptions: @options
      cmds: cmds
      vars: vars

    if cluster.isMaster
      exports.workers = workers 
      exports.cw = cw

    return exports


  changeWorker: (workerId)->
    for key, worker of cluster.workers
      if worker.id == workerId
        @server.forwardToWorker @, worker
        return

    @send "Could not find worker with worker ID '#{workerId}'"


  getCommands: ()->
    exported = @repl.context.exported
    commands = (key for key in Object.keys(exported) when typeof exported[key] == 'function')

    signatureAsString = (name, func)-> "#{key}(#{doc.docArgsAsString(func).join(', ')})"

    longest = 0
    for key in commands
      longest = signatureAsString(key, exported[key]).length if key.length > longest

    indentBy = longest + 6

    descriptions = []
    for key in commands
      func = exported[key]
      signature = terminal.rpad signatureAsString(key, func), indentBy
      described = ''
      terminal.printWrapped doc.docAsString(func), 80, indentBy, (out)->
        described += out + "\n"

      descriptions.push "#{signature}#{described.substring(indentBy)}"

    if descriptions.length > 0
      descriptions.unshift ''
      descriptions.unshift "#{terminal.rpad('--', indentBy)}--"
      descriptions.unshift "#{terminal.rpad('function', indentBy)}documentation"
      descriptions.unshift ''
      descriptions.unshift "(#{commands.length}) commands in the local REPL context".cyan
    else
      descriptions = ["There are no commands in the local REPL context".cyan]

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
      descriptions.unshift "(#{vars.length}) variables in the local REPL context".cyan
    else
      descriptions = ["There are no variables in the local REPL context".cyan]

    return descriptions.join "\n"


  getWorkers: ()->
    active = Object.keys(cluster.workers).length
    plural = if active != 1 then 's' else ''
    nonEssentialLineBreak = if active > 0 then "\n" else ''
    """
    #{"(#{active}) worker active#{plural}#{nonEssentialLineBreak}".cyan}
    #{@server.describeWorkers()}
    """


  welcome: ()->
    @write [@TERM_CODES.clear,  @TERM_CODES.zeroPos,  @getWelcomeMessage()].join ''


  getWelcomeMessage: ()->
    title = 'Welcome'.cyan.bold
    hint = 'Hint: use cmds() to print the current exports available to you'

    if cluster.isMaster
      """
      #{title} #{@options.name}[Cluster]

      #{@indent(@getWorkers(), 2)}

      #{hint}

      #{@options.prompt}
      """
    else 
      """
      #{title} to #{@options.name}[Worker]

      #{hint}

      #{@options.prompt}
      """


module.exports = ReplrClient
