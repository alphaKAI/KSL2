#encoding:utf-8
require "yaml"
require_relative "./kslClass.rb"

module KSLPlugin
=begin
  Pluginの実態
  すべてのプラグインはこれのインスタンスとして動く
=end
  class Plugin
    attr_reader :command, :script, :level, :elements
    @elements    = ["command", "script", "level"] 
    @commandName = String.new
    @script      = String.new
    @level       = 0 # 0: normal, 1:root
    @evaled      = false
    def initialize(hash)
      @commandName = hash["command"]
      @script      = hash["script"].gsub(/\n/, ";")
      @velvel      = hash["level"]
    end

    def exec(args = [])
      return 1 if @level == 1 #Need to auth then call rootExec as own risk
      eval(@script) unless @evaled
      if args.length > 0
        argString = args.join(" ")
        if argString;end
        eval("#{@commandName} argString")
      else
        eval("#{@commandName}")
      end
    end

    def rootExec(args = [])
      eval(@script) unless @evaled
      if args.length > 0
        argString = args.join(" ")
        if argString;end
        eval("#{@commandName} argString")
      else
        eval("#{@commandName}")
      end
    end
  end
=begin
  Pluginをパースし、Plugin classのインスタンスを作成する
=end
  class PluginLoader
    def load(filepath)
      unless File.exists?(filepath)
        puts "[KSL PluginLoader load Error] FILE NOT FOUND - #{filepath}"
        return false
      end

      data = YAML.load(File.read(filepath))
      elements = ["command", "level", "script"]
      if data.keys - elements == [] and elements - data.keys == []
        return Plugin.new(data)
      else
        puts "This plugin is wrong."
        puts "script path : #{filepath}"
        puts "wrong point : #{data.keys - elements == [] ? elements - data.keys : data.keys - elements}"
        return false
      end
    end
  end
=begin
  プラグインを管理するクラス
=end
  class PluginStore
    @plugins = Hash.new
    
    def initialize(kslInstance)
      @ksl = kslInstance
    end

    def addPlugin(plugin)
      unless @plugins[plugin.command]
        @plugins[plugin.command] = plugin
      end
    end
  end
=begin
  上記クラスを用いたプラグインエンジンの実装
=end
  class PluginEngine
   def initialize(kslInstance)
      @ksl = kslInstance
      @kpl = PluginLoader.new(@ksl)
      @kpstore = PluginStore.new(@ksl)
   end
  end
end

def test
  plugin = KSLPlugin::PluginLoader.new.load("./sample.yaml")
  p plugin
  plugin.exec ["alphaKAI"]
end
test
