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

require "readline"
require "socket"

include KSLUsers

module KSLCommandLine
  class KSLCommandLine
    include KSLUtils

    def initialize
      @currentMode = :normalMode
      user         = KSLUsers::KSLUser.new(Process::UID.eid == 0 ? 1 : 0, ENV["USER"])
      @users       = KSLUsers::KSLUsers.new(user)
      @kpengine    = KSLPlugin::PluginEngine.new @users.currentUser
      @hostname    = Socket.gethostname
      @pluginDir   = $srcPath + "/plugins"

      Dir.entries(@pluginDir).each do |e|
        if e =~ /yaml$/
          @kpengine.kpstore.addPlugin @kpengine.kpl.load(@pluginDir + "/" + e)
        end# End of if
      end# End of each

      @embeddedCommands = ["exit", "sudo", "cd", "sherb",
                           "help", "users", "login", "createuser",
                           "pluginManager", "enable", "disable", "list",
                           "rbitpr", "aliases", "alias", "unalias", "saveConfig"]
      @pluginCommands   = @kpengine.kpstore.plugins.keys
      @commands         = @embeddedCommands + @pluginCommands

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
          end# End of if

          if commands[indexOfCommands] == nil
            commands[indexOfCommands] = arg + " "
          else
            commands[indexOfCommands] += arg + " "
          end# End of if
        end# End of each

        pipes = Array.new

        if pipeFlag
          pipes = Array.new(commands.count - 1){ IO.pipe }
          pipes = [STDIN, pipes.flatten.reverse, STDOUT].flatten
        end# End of if

        commands.each do |command|
          rr = nil
          ww = nil

          if pipeFlag
            rr, ww  = pipes.shift 2
            $stdin  = rr if rr
            $stdout = ww if ww
          end# End of if

          # Embedded Functions
          inputLine = command
          inputLine.gsub!("~/", ENV["HOME"] + "/")
          redirectFlag = false

          if inputLine =~ /.*\s>(.*)/
            fname   = $1.delete(" ")
            $stdout = File.open(fname, "w")
            inputLine.gsub!(/\s?>.*/, "")
            redirectFlag = true
          end# End of if

          # Todo: remove split -> regex
          if inputLine =~ /^exit/
            if @users.exit
              if @users.nestedLogin
                @users.logout
              else
                return :exitKSL
              end# End of if
            end# End of if
          elsif inputLine =~ /^cd/
            args = inputLine.split

            if args[1].to_s.empty?
              args[1] = @users.currentUser.home
            end# End of if

            unless File.exist?(args[1])
              puts "no such file or directory: \'#{args[1]}\'"
            else
              Dir.chdir(args[1])
            end#End of if
          elsif inputLine =~ /^help/
            puts "commands:"
            
            @commands.each do |e|
              puts "  " + e.to_s
            end# End of if
          elsif inputLine =~ /^sudo/
            @users.currentUser.sudo
          elsif inputLine =~ /^\.\D+.*$/
            inputLine = inputLine[1..-1]
            puts "system => #{inputLine}"
            system(inputLine)
          elsif inputLine =~ /^sherb/
            pluginName = inputLine.split[1]
            print "=> "
            lines = ""

            STDIN.each_line do |input|
              print "=> "
              lines += input
            end# End of if

            pluginHash = {
              "command" => pluginName,
              "level"   => 0,
              "script"  => lines
            }

            @kpengine.kpstore.addPlugin @kpengine.kpl.loadByHash(pluginHash)
          elsif inputLine =~ /^users/
            @users.users.each do |user|
              puts user
            end# End of each
          elsif inputLine =~ /^login/
            @users.login inputLine.split[1]
          elsif inputLine =~ /^createuser/
            userName = inputLine.split[1]
            if userName == "" || userName == nil
              puts "Empty user name is not allowed."
            else
              @users.addUser userName
            end# End of if
          # Plugin Manager
          elsif inputLine =~ /^pluginManager/
            pluginLine = inputLine.split("pluginManager")[1]
            if pluginLine =~ /enable/
              @kpengine.enable pluginLine.split[1]
            elsif pluginLine =~ /disable/
              @kpengine.disable pluginLine.split[1]
            elsif pluginLine =~ /list/
              @kpengine.kpstore.showPlugins
            end# End of if
          elsif inputLine =~ /^rbitpr/
            eval(inputLine.split("rbitpr")[1])
          elsif inputLine =~ /^aliases/
            p @users.currentUser.aliases
          elsif inputLine =~ /^alias/
            inputLine.gsub!("alias ", "")
            unless inputLine.include?("=")
              puts "[Error -> Add alias failed] : Your foramt is wrong"
            else
              puts "Add alias : #{{inputLine.split("=")[0].strip => inputLine.split("=")[1..-1].join("=").strip}}"
              @users.currentUser.addAlias({
                :contracted => inputLine.split("=")[0].strip,
                :expanded   => inputLine.split("=")[1..-1].join("=").strip
              })
            end# End of if
          elsif inputLine =~ /^unalias/
            inputLine.split[1..-1].each do |e|
              @users.currentUser.unalias(e)
            end# End of each
          elsif inputLine =~ /^saveConfig/
            @users.currentUser.saveConfig
          else
            unless @kpengine.engine inputLine
              if File.directory?(inputLine.split[0])
                Dir.chdir(inputLine.split[0])
                break
              end# End of if

              puts "\"#{inputLine.split[0]}\" is not a KSL2 Command"

              @commands.each do |e|
                if 1 <= match(e, inputLine.split[0].to_s) || 1 <= match(inputLine.split[0].to_s, e)
                  e = "\e[35m" +  e + "\e[0m"
                  puts "Did you mean \"#{e}\"?"
                end# End of if
              end# End of each
            end#End of unless
          end# End of if

          $stdout = STDOUT if redirectFlag

          if pipeFlag
            rr.close if rr && rr != STDIN
            ww.close if ww && ww != STDOUT
            $stdout = STDOUT
            $stdin  = STDIN
          end# End of if
        end# End of each
      end# End of loop
    end# End of method

    private
    def getPrompt
      if @users.currentUser.root?
        return "# "
      else
        return "% "
      end# End of if
    end# End of method
  end# End of class
end# End of module

if __FILE__ == $0
  kcl = KSLCommandLine::KSLCommandLine.new
  kcl.commandLinE
end
