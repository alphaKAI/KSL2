#encoding:utf-8
=begin
  KSLPlugin Module

  The Plugin Engine for KSL Plugin System.

  Copyright (C) 2015 alphaKAI http://alpha-kai-net.info
  The MIT License.
=end

require "yaml"

module KSLPlugin
=begin
  Plugin Class
  All of the plugins runs as instance of this class.
=end
  PLUGIN_ELEMENTS = ["command", "level", "script"]
  class Plugin
    attr_reader :commandName, :script, :level
    attr_accessor :enabled
    def initialize(hash)
      @commandName = hash["command"]
      @script      = hash["script"]
      @level       = hash["level"]
      @enabled     = false
      @evaled      = false
    end

    def callable?(args)
      arr = self.method(@commandName.to_sym).parameters.flatten
      
      unless arr.include?(:req)
        return true
      end

      reqs = arr.count(:req)
      
      if reqs != args.length
        puts "\"#{@commandName}\" command require #{reqs} arguments"
        return false
      else
        return true
      end
    end

    def exec(args = [])
      eval(@script) unless @evaled
      
      if args.length > 0
        argString = args.map{|elem| "\"#{elem}\"" }.join(", ")
        eval("#{@commandName} #{argString}") if callable?(args)
      else
        eval("#{@commandName}") if callable?(args)
      end

      return true
    end
  end

=begin
  PluginLoader Class
  Parse the plugin file and create an instance of Plugin class.
=end
  class PluginLoader
    def load(filepath)
      unless File.exists?(filepath)
        puts "[KSL PluginLoader load Error] FILE NOT FOUND - #{filepath}"
        return false
      end

      data = YAML.load(File.read(filepath))
      plugin = loadByHash(data)

      if plugin == false
        puts "This plugin is wrong."
        puts "script path : #{filepath}"
        puts "wrong point : #{data.keys - PLUGIN_ELEMENTS == [] ? PLUGIN_ELEMENTS - data.keys : data.keys - PLUGIN_ELEMENTS}"
        return false
      end

      return plugin
    end

    def loadByHash(data)
      if data.keys - PLUGIN_ELEMENTS == [] and PLUGIN_ELEMENTS - data.keys == []
        return Plugin.new(data)
      else
        return false
      end
    end
  end

=begin
  PluginStore Class
  Manegemnt the plugins.
=end
  class PluginStore
    attr_reader :plugins
    def initialize(kslUser)
      @ksluser = kslUser
      @plugins = Hash.new
    end

    def addPlugin(plugin)
      unless @plugins.keys.include?(plugin.commandName)
        @plugins[plugin.commandName] = plugin
        enable(plugin.commandName)
      end
    end
  
    def enable(pluginName)
      if self.exists?(pluginName)
        @plugins[pluginName].enabled = true
        return true
      else
        puts "[Error fail to enable plugin] : Not Found - #{pluginName}"
        return false
      end
    end
    
    def disable(pluginName)
      if self.exists?(pluginName)
        @plugins[pluginName].enabled = false
        return true
      else
        puts "[Error fail to disable plugin] : Not Found - #{pluginName}"
        return false
      end
    end

    def exists?(pluginName)
      @plugins.keys.each do |name|
        return true if name == pluginName
      end

      return false
    end

    def showPlugins
      @plugins.each do |pluginName, specifics|
        puts "#{pluginName} - #{specifics.enabled ? "enable" : "disable"}"
      end
    end

    def exec(line)
      thisPlugin = @plugins[line["command"]]

      if thisPlugin.enabled
        permitExecute = false
      
        if thisPlugin.level == 0
          permitExecute = true
        else
          if @ksluser.root?
            permitExecute = true
          else
            if @ksluser.auth("!! This plugin require root privilege. If you wish to use this, you at your own risk.  !!")
              permitExecute = true
            else
              puts "auth failed"
              return false
            end
          end
        end

        if permitExecute
          thisPlugin.exec line["args"]
          return true
        else
          puts "You are not permitted to execute this command."
          return false
        end

      else
        puts "#{line["command"]} is disabled. If you want to use this plugin, use must enable this plugin."
        return false
      end
    end
  end

=begin
  PluginEngine Class
  Implementation of the PluginEngine.
=end
  class PluginEngine
    attr_accessor :kpl, :kpstore
    def initialize(kslUser)
      @ksluser = kslUser
      @kpl     = PluginLoader.new
      @kpstore = PluginStore.new(@ksluser)
    end

    def engine(line)
      line = splitLine(line)
      if @kpstore.exists?(line["command"])
        if @kpstore.exec(line)
          return true
        else
          return false
        end
      else
        return false
      end
    end

    def enable(pluginName)
      @kpstore.enable(pluginName)
    end

    def disable(pluginName)
      @kpstore.disable(pluginName)
    end

    private
    def splitLine(line)
      return {
        "command" => line.split[0],
        "args"    => line.split[1..-1]
      }
    end
  end
end
