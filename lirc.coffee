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
  fs = require "fs"
  os = require "os"

  # ###LircPlugin class
  class LircPlugin extends env.plugins.Plugin

    init: (app, @framework, @config) =>
      lirc_node.init();
      deviceConfigDef = require("./device-config-schema")
      
      # I know this isn't optimal but the init function of node_lirc needs some time before it is done.
      # This makes the pimatic rule engine fail, at launch and the rules to be disabled.
      setTimeout ( ->
        remoteList = lirc_node.remotes
        fs.writeFile __("%s/cached_remotes_lirc.json", os.tmpdir()), JSON.stringify(lirc_node.remotes), (error) ->
          env.logger.error("Error writing remote cache file.", error) if error
      ), 10000
      
      Promise.promisifyAll(lirc_node)

      @framework.ruleManager.addActionProvider(new LircActionProvider @framework, config)
      @framework.deviceManager.registerDeviceClass("LircReceiver", {
        configDef: deviceConfigDef.LircReceiver,
        createCallback: (config) ->
          device = new LircReceiver(config)
          return device
      })

  class LircActionProvider extends env.actions.ActionProvider

    constructor: (@framework, @config) ->
      return

    parseAction: (input, context) =>

      # Load the cached remote file.
      try remoteList = JSON.parse(fs.readFileSync(__("%s/cached_remotes_lirc.json", os.tmpdir()), "utf8"))
      catch e then remoteList = {}
      remote = ""
      command = ""
      match = null

      m = M(input, context)
        .match('set ', optional: yes)
        .match(['lirc'])

      m.match [' remote: '], (m) ->
        m.match _.keys(remoteList), (next, r) ->
          remote = r
          next.match [' command: '], (m) ->
            m.match _.valuesIn(remoteList[remote]), (m, c) ->
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
  
  class LircReceiver extends env.devices.Sensor
    remote: null
    command: null
    idleTime = 0
  
    attributes:
      remote:
        description: 'last remote used'
        type: "string"
      command:
        description: 'last key pressed'
        type: "string"
  
  
    constructor: (@config) ->
      @name = config.name
      @id = config.id
      super()

      @listenForIR()
      setInterval( ( => @resetLircOutput() ), 1000)

    resetLircOutput: ->
      if @command?
        idleTime += 1
        if idleTime > 60
          @remote = null
          @command = null
          @emit "remote", @remote
          @emit "command", @command
          idleTime = 0
          env.logger.debug("Resetting the lirc input to null")
      
    listenForIR: () ->
      lirc_node.addListener (data) =>
        env.logger.debug("Data received remote %s, command %s", data.remote, data.key)
        @remote = data.remote
        @command = data.key
        @emit "remote", @remote
        @emit "command", @command
        idleTime = 0
        
    getRemote: -> Promise.resolve(@remote)
    getCommand: -> Promise.resolve(@command)


  # Create a instance of my plugin
  lircPlugin = new LircPlugin()

  # and return it to the framework.
  return lircPlugin
