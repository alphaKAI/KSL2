#encoding:utf-8
=begin
  KSLCommandLine Module

  The implementation of ksl frontend.

  Copyright (C) 2015 alphaKAI http://alpha-kai-net.info
  The MIT License.
=end

$srcPath = $KSL_Bin_Path + "/../src/"
require $srcPath + "kslPlugin.rb"
require $srcPath + "kslUsers.rb"
require $srcPath + "kslUtils.rb"
require $srcPath + "kslExecuteMachine.rb"
require "readline"
require "socket"

include KSLUsers

module KSLCommandLine
  class KSLCommandLine
    include KSLUtils

    def initialize
      @currentMode = :normalMode
      user         = KSLUsers::KSLUser.new(Process::UID.eid == 0 ? 1 : 0, ENV["USER"])
      @users       = KSLUsers::KSLUsers.new user
      @kpengine    = KSLPlugin::PluginEngine.new @users.currentUser
      @kemachine   = KSLExecuteMachine::ExecuteMachine.new
      @hostname    = Socket.gethostname
      @pluginDir   = $srcPath + "/plugins"

      Dir.entries(@pluginDir).each do |e|
        if e =~ /yaml$/
          @kpengine.kpstore.addPlugin @kpengine.kpl.load(@pluginDir + "/" + e)
        end
      end

      @embeddedCommands = ["exit", "sudo", "cd", "sherb",
                           "help", "users", "login", "createuser",
                           "pluginManager", "enable", "disable", "list",
                           "rbitpr", "aliases", "alias", "unalias", "saveConfig"]
      @pluginCommands   = @kpengine.kpstore.plugins.keys
      @commands         = @embeddedCommands + @pluginCommands

      @kemachine.registerEventsByHash({
        :exit => {
          :pattern => /^exit/,
          :lambda  => lambda do |arguments, inputLine|
            if @users.exit
              if @users.nestedLogin
                @users.logout
              else
                return :exitKSL
              end
            end
          end
        },
        :cd => {
          :pattern => /^cd/,
          :lambda  => lambda do |arguments, inputLine|
            if arguments[1].to_s.empty?
              arguments[1] = @users.currentUser.home
            end

            unless File.exist? arguments[1]
              puts "no such file or directory: \'#{arguments[1]}\'"
            else
              Dir.chdir arguments[1]
            end
          end
        },
        :help => {
          :pattern => /^help/,
          :lambda  => lambda do |arguments, inputLine|
            puts "commands:"

            @commands.each do |e|
              puts "  " + e.to_s
            end
          end
        },
        :sudo => {
          :pattern => /^sudo/,
          :lambda  => lambda do |arguments, inputLine|
            @users.currentUser.sudo
          end
        },
        :dot => {
          :pattern => /^\.\D+.*$/,
          :lambda => lambda do |arguments, inputLine|
            inputLine = inputLine[1..-1]

            puts "system => #{inputLine}"

            system(inputLine)
          end
        },
        :sherb => {
          :pattern =>  /^sherb/,
          :lambda  => lambda do |arguments, inputLine|
            pluginName = arguments[1]

            print "=> "
            lines = ""

            STDIN.each_line do |input|
              print "=> "
              lines += input
            end

            pluginHash = {
              "command" => pluginName,
              "level"   => 0,
              "script"  => lines
            }

            @kpengine.kpstore.addPlugin @kpengine.kpl.loadByHash(pluginHash)
          end
        },
        :users => {
          :pattern => /^users/,
          :lambda  => lambda do |arguments, inputLine|
            @users.users.each do |_user|
              puts _user
            end
          end
        },
        :login => {
          :pattern => /^login/,
          :lambda  => lambda do |arguments, inputLine|
            @users.login arguments[1]
          end
        },
        :createuser => {
          :pattern => /^createuser/,
          :lambda  => lambda do |arguments, inputLine|
            userName = arguments[1]

            if userName == "" || userName == nil
              puts "Empty user name is not allowed."
            else
              @users.addUser userName
            end
          end
        },
        :pluginManager => {
          :pattern => /^pluginManager/,
          :lambda  => lambda do |arguments, inputLine|
            pluginLine = inputLine.split("pluginManager")[1]

            if pluginLine =~ /enable/
              @kpengine.enable pluginLine.split[1]
            elsif pluginLine =~ /disable/
              @kpengine.disable pluginLine.split[1]
            elsif pluginLine =~ /list/
              @kpengine.kpstore.showPlugins
            end
          end
        },
        :rbitpr => {
          :pattern => /^rbitpr/,
          :lambda  => lambda do |arguments, inputLine|
            eval(inputLine.split("rbitpr")[1])
          end
        },
        :aliases => {
          :pattern => /^aliases/,
          :lambda  => lambda do |arguments, inputLine|
            p @users.currentUser.aliases
          end
        },
        :alias => {
          :pattern => /^alias/,
          :lambda  => lambda do |arguments, inputLine|
            inputLine.gsub!("alias ", "")
            
            unless inputLine.include?("=")
              puts "[Error -> Add alias failed] : Your foramt is wrong"
            else
              puts "Add alias : #{{inputLine.split("=")[0].strip => inputLine.split("=")[1..-1].join("=").strip}}"
              @users.currentUser.addAlias({
                :contracted => inputLine.split("=")[0].strip,
                :expanded   => inputLine.split("=")[1..-1].join("=").strip
              })
            end
          end
        },
        :unalias => {
          :pattern => /^unalias/,
          :lambda  => lambda do |arguments, inputLine|
            inputLine.split[1..-1].each do |e|
              @users.currentUser.unalias(e)
            end
          end
        },
        :saveConfig => {
          :pattern => /^saveConfig/,
          :lambda  => lambda do |arguments, inputLine|
            @users.currentUser.saveConfig
          end
        },
        :default => {
          :pattern => nil,
          :lambda  => lambda do |arguments, inputLine|
            unless @kpengine.engine inputLine
              if File.directory? arguments[0]
                Dir.chdir arguments[0]
                break
              end

              puts "\"#{arguments[0]}\" is not a KSL2 Command"

              @commands.each do |e|
                if 1 <= match(e, arguments[0].to_s) || 1 <= match(arguments[0].to_s, e)
                  e = "\e[35m" +  e + "\e[0m"
                  puts "Did you mean \"#{e}\"?"
                end
              end
            end
          end
        }
      })

      puts "loaded plugins:"
      @kpengine.kpstore.showPlugins
    end

    def commandLine
      loop do
        @pluginCommands = @kpengine.kpstore.plugins.keys
        @commands       = @embeddedCommands + @pluginCommands

        # initialize
        $stdin  = STDIN
        $stdout = STDOUT

        commands = @commands
        entries  = Dir.entries(Dir.pwd).select do |e| !(e =~ /^\..*/) end
        entries.delete(nil)
        commands += entries
        commands += @users.currentUser.aliases.keys

        Readline.completion_proc = proc do |word|
          commands.grep(/\A#{Regexp.quote word}/)
        end

        prompt    = "\r\e[36m#{@users.currentUser.name}\e[0m\e[36m@#{@hostname}\e[0m \e[31m[KSL2]\e[0m \e[1m#{pathCompress(Dir.pwd)}\e[0m #{getPrompt}"
        inputLine = Readline.readline(prompt, true)

        # Alias -> Replace by alias table
        unless inputLine.delete(" ") == ""
          commandName = replaceStringbyTable(@users.currentUser.aliases, inputLine.split[0], :headFlag => true)
          inputLine   = ([commandName] + inputLine.split[1..-1]).join(" ")
        end

        pipeFlag = false
        commands = Array.new
        indexOfCommands = 0

        #Todo : Change - split pattern
        inputLine.split.each do |arg|
          if arg == "|"
            pipeFlag = true
            indexOfCommands += 1
            next
          elsif arg == "&&" || arg == ";"
            indexOfCommands += 1
            next
          end

          if commands[indexOfCommands] == nil
            commands[indexOfCommands] = arg + " "
          else
            commands[indexOfCommands] += arg + " "
          end
        end

        pipes = Array.new

        if pipeFlag
          pipes = Array.new(commands.count - 1){ IO.pipe }
          pipes = [STDIN, pipes.flatten.reverse, STDOUT].flatten
        end

        commands.each do |command|
          rr = nil
          ww = nil

          if pipeFlag
            rr, ww  = pipes.shift 2
            $stdin  = rr if rr
            $stdout = ww if ww
          end

          # Embedded Functions
          inputLine = command
          inputLine.gsub!("~/", ENV["HOME"] + "/")
          redirectFlag = false

          if inputLine =~ /.*\s>(.*)/
            fname   = $1.delete(" ")
            $stdout = File.open(fname, "w")
            inputLine.gsub!(/\s?>.*/, "")
            redirectFlag = true
          end

          if :exitKSL == @kemachine.execute(inputLine)
            exit
          end

          $stdout = STDOUT if redirectFlag

          if pipeFlag
            rr.close if rr && rr != STDIN
            ww.close if ww && ww != STDOUT
            $stdout = STDOUT
            $stdin  = STDIN
          end
        end
      end
    end

    private
    def getPrompt
      if @users.currentUser.root?
        return "# "
      else
        return "% "
      end
    end
  end
end

if __FILE__ == $0
  kcl = KSLCommandLine::KSLCommandLine.new
  kcl.commandLine
end
