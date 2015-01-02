repl = require('repl')
ReplrServer = require('./ReplrServer')
ReplrWorkerPassthrough = require('./ReplrWorkerPassthrough')

# Expose simple REPL creation and worker REPL options
funcs = 
  create: (options)-> 
    return new ReplrServer(options)

  configureAsWorker: (options)-> 
    ReplrWorkerPassthrough::workerOptions = options

# Setup passthrough by listening to process messages from cluster host process
ReplrWorkerPassthrough::setup()

module.exports = funcs
