merge = require('merge')
ReplrServer = require('./ReplrServer')
ReplrClient = require('./ReplrClient')
ReplrEvents = require('./ReplrEvents')

class ReplrWorkerPassthrough extends ReplrServer

  @::forwarded = []
  @::workerOptions = {}

  @::setup = ()->
    forwarded = ReplrWorkerPassthrough::forwarded
    process.on 'message', (msg, handle)->
      if msg && typeof msg == 'object' && msg.type == ReplrEvents::WORKER_RECEIVE
        options = merge msg.options, ReplrWorkerPassthrough::workerOptions

        # Create our passthrough
        passthrough = new ReplrWorkerPassthrough(options)
        passthrough.open handle

        forwarded.push passthrough

        # Ensure we remove our passthrough when our socket gets closed
        handle.on 'end', ()->
          forwarded.splice forwarded.indexOf(passthrough), 1


  constructor: (options, start=false)->
    super(options, start)


module.exports = ReplrWorkerPassthrough
