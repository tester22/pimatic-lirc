# #Lirc plugin

# This plugin gives functionality to pimatic to control lirc (ir remotes).
module.exports = (env) ->

  # Require the  bluebird promise library
  Promise = env.require 'bluebird'

  # Require the [cassert library](https://github.com/rhoot/cassert).
  assert = env.require 'cassert'
  _ = require 'lodash'
  M = env.matcher

  # Require the [lirc_node](https://github.com/alexbain/lirc_node) library
  lirc_node = require 'lirc_node'

  # ###LircPlugin class
  class LircPlugin extends env.plugins.Plugin

    init: (app, @framework, @config) =>
      lirc_node.init()
      Promise.promisifyAll(lirc_node)

      @framework.ruleManager.addActionProvider(new LircActionProvider @framework, config)

  # Create a instance of my plugin
  LircPlugin = new LircPlugin()

  class LircActionProvider extends env.actions.ActionProvider

    constructor: (@framework, @config) ->
      return

    parseAction: (input, context) =>
    
      remote = ""
      command = ""
      match = null

      m = M(input, context)
        .match('set ', optional: yes)
        .match(['lirc'])

      m.match [' remote: '], (m) ->
        m.match _.keys(lirc_node.remotes), (next, r) ->
          remote = r
          next.match [' command: '], (m) ->
            m.match _.valuesIn(lirc_node.remotes[remote]), (m, c) ->
              command = c
              match = m.getFullMatch()

      if match?
        # either variable or color should be set
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new LircActionHandler(
            @framework, remote, command
          )
        }

  class LircActionHandler extends env.actions.ActionHandler

    constructor: (@framework, @remote, @command) ->

    executeAction: (simulate, context) ->
        if simulate
          # just return a promise fulfilled with a description about what we would do.
          return __(
            "would send ir command \"%s\" with remote \"%s\"",
            @command, @remote)
        else
            lirc_node.irsend.send_once(@remote, @command, -> return __("Sending command \"%s\" with remote \"%s\"",
            @command, @remote))
            return __("Sending command \"%s\" with remote \"%s\"", @command, @remote)
      

  module.exports.LircActionHandler = LircActionHandler

  # and return it to the framework.
  return LircPlugin
