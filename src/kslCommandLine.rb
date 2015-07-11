#encoding:utf-8
=begin
  KSLCommandLine Module

  The implementation of ksl frontend.

  Copyright (C) 2015 alphaKAI http://alpha-kai-net.info
  The MIT License.
=end

if __FILE__ == $0
  require "./kslPlugin.rb"
  require "./kslUsers.rb"
  require "./kslUtils.rb"
else
  $srcPath = $KSL_Bin_Path + "/../src/"
  require $srcPath + "kslPlugin.rb"
  require $srcPath + "kslUsers.rb"
  require $srcPath + "kslUtils.rb"
end

require "readline"
require "socket"
require "trigram"

include KSLUsers

module KSLCommandLine
  class KSLCommandLine
    include KSLUtils

    def initialize
      @currentMode = :normalMode
      user = KSLUsers::KSLUser.new(Process::UID.eid == 0 ? 1 : 0, ENV["USER"])
      @users = KSLUsers::KSLUsers.new(user)

      @kpengine    = KSLPlugin::PluginEngine.new @users.currentUser
      @hostname    = Socket.gethostname

      if __FILE__ == $0
        @pluginDir = Dir.pwd + "/plugins"
      else
        @pluginDir = $srcPath + "/plugins"
      end

      Dir.entries(@pluginDir).each do |e|
        if e =~ /yaml$/
          @kpengine.kpstore.addPlugin @kpengine.kpl.load(@pluginDir + "/" + e)
        end
      end

      @embeddedCommands = ["exit", "sudo", "cd", "sherb", "help", "users", "login", "createuser"]
      @pluginCommands   = @kpengine.kpstore.plugins.keys
      @commands         = @embeddedCommands + @pluginCommands
      puts "loaded plugins:"
      @kpengine.kpstore.showPlugins
    end

    def commandLine
      loop do
        @pluginCommands   = @kpengine.kpstore.plugins.keys
        @commands         = @embeddedCommands + @pluginCommands

        #initialize
        $stdin  = STDIN
        $stdout = STDOUT

        commands = @commands
        entries = Dir.entries(Dir.pwd).map do |e|
          next if e =~ /^\..*/
          e
        end
        entries.delete(nil)
        commands += entries

        Readline.completion_proc = proc{|word|
          commands.grep(/\A#{Regexp.quote word}/)
        }

        prompt = "\r\e[36m#{@users.currentUser.name}\e[0m\e[36m@#{@hostname}\e[0m \e[31m[KSL2]\e[0m \e[1m#{pathCompress(Dir.pwd)}\e[0m #{getPrompt}"
        inputLine = Readline.readline(prompt, true)
        #print "\r\e[36m#{@currentUser.name}\e[0m\e[36m@#{@hostname}\e[0m \e[31m[KSL2]\e[0m \e[1m#{pathCompress(Dir.pwd)}\e[0m #{getPrompt}"
        #inputLine = STDIN.gets.chomp

        pipeFlag = false
        commands = []
        i = 0
        inputLine.split.each do |arg|
          if arg == "|"
            pipeFlag = true
            i += 1
            next
          elsif arg == "&&" || arg == ";"
            i += 1
            next
          end

          if commands[i] == nil
            commands[i] = arg + " "
          else
            commands[i] += arg + " "
          end
        end

        pipes = []
        if pipeFlag
          pipes = Array.new(commands.count - 1){ IO.pipe }
          pipes = [STDIN, pipes.flatten.reverse, STDOUT].flatten
        end

        commands.each do |command|
          rr = nil
          ww = nil
          if pipeFlag
            rr, ww = pipes.shift 2
            $stdin  = rr if rr
            $stdout = ww if ww
          end

          #Embedded Functions
          inputLine = command
          inputLine.gsub!("~/", ENV["HOME"] + "/")

          redirectFlag = false
          if inputLine =~ /.*\s>(.*)/
            $stdout = File.open($1, "w")
            inputLine.gsub!(/\s?>.*/, "")
            redirectFlag = true
          end

          if inputLine =~ /^exit/
            if @users.exit
              if @users.nestedLogin
                @users.logout
              else
                return :exitKSL
              end
            end
          elsif inputLine =~ /^cd/
            args = inputLine.split
            if args[1].to_s.empty?
              args[1] = @users.currentUser.home
            end
            unless File.exist?(args[1])
              puts "no such file or directory: \'#{args[1]}\'"
            else
              Dir.chdir(args[1])
            end
          elsif inputLine =~ /^help/
            puts "commands:"
            @commands.each do |e|
              puts "  " + e.to_s
            end
          elsif inputLine =~ /^sudo/
            @users.currentUser.sudo
          elsif inputLine =~ /^\.\D+$/
            inputLine = inputLine[1..inputLine.size-1]
            puts "system => #{inputLine}"
            system(inputLine)
          elsif inputLine =~ /^sherb/
            pluginName = inputLine.split[1]
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
          elsif inputLine =~ /^users/
            @users.users.each do |user|
              puts user
            end
          elsif inputLine =~ /^login/
            @users.login inputLine.split[1]
          elsif inputLine =~ /^createuser/
            userName = inputLine.split[1]
            if userName == "" || userName == nil
              puts "Empty user name is not allowed."
            else
              @users.addUser userName
            end
          else
            unless @kpengine.engine inputLine
              flag = false

              if File.directory?(inputLine.split[0])
                Dir.chdir(inputLine.split[0])
                break
              end

              unless flag
                puts "\"#{inputLine.split[0]}\" is not a KSL2 Command"
                @commands.each do |e|
                  if 1 <= match(e, inputLine.split[0].to_s) || 1 <= match(inputLine.split[0].to_s, e)
                    e = "\e[35m" +  e + "\e[0m"
                    puts "Did you mean \"#{e}\"?"
                  end
                end
              end
            end
          end

          if redirectFlag
            $stdout = STDOUT
          end

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
  kcl.commandLinE
end
