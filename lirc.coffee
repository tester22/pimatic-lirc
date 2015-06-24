# #Lirc plugin

# This plugin gives functionality to pimatic to control lirc (ir remotes).
module.exports = (env) ->

  # Require the  bluebird promise library
  Promise = env.require 'bluebird'

  # Require the [cassert library](https://github.com/rhoot/cassert).
  assert = env.require 'cassert'
  M = env.matcher

  # Require the [lirc_node](https://github.com/alexbain/lirc_node) library
  lirc_node = require 'lirc_node'

  # ###LircPlugin class
  class LircPlugin extends env.plugins.Plugin

    init: (app, @framework, @config) =>
      lirc_node.init()
      env.logger.info("Hello World")
      Promise.promisifyAll(lirc_node)

      @framework.ruleManager.addActionProvider(new LircActionProvider @framework, config)

  # Create a instance of my plugin
  LircPlugin = new LircPlugin()

  class LircActionProvider extends env.actions.ActionProvider

    constructor: (@framework, @config) ->

    parseAction: (input, context) =>

      # Helper to convert 'some text' to [ '"some text"' ]
      strToTokens = (str) => ["\"#{str}\""]

      m = M(input, context)
        .match('set ', optional: yes)
        .match(['lirc'])

      options = ["remote", "command"]
      optionsTokens = {}

      env.logger.info(lirc_node.remotes)

      for opt in options
        do (opt) =>
          optionsTokens[opt] = strToTokens @config[opt]
          next = m.match(" #{opt}:").matchStringWithVars( (m, tokens) =>
            optionsTokens[opt] = tokens
          )
          if next.hadMatch() then m = next

      if m.hadMatch()
        match = m.getFullMatch()
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new LircActionHandler(
            @framework, optionsTokens
          )
        }
      else
        return null

  class LircActionHandler extends env.actions.ActionHandler

    constructor: (@framework, @optionsTokens) ->

    executeAction: (simulate, context) ->
      LircOptions = {}
      awaiting = []
      for name, tokens of @optionsTokens
        do (name, tokens) =>
          p = @framework.variableManager.evaluateStringExpression(tokens).then( (value) =>
            LircOptions[name] = value
          )
          awaiting.push p
      Promise.all(awaiting).then( =>
        if simulate
          # just return a promise fulfilled with a description about what we would do.
          return __(
            "would send ir command \"%s\" with remote \"%s\"",
            LircOptions.command, LircOptions.remote)
        else

            lirc_node.irsend.send_once(LircOptions.remote, LircOptions.command, -> return __("Command sent"))
            return __("Command sent")
      )

  module.exports.LircActionHandler = LircActionHandler

  # and return it to the framework.
  return LircPlugin
