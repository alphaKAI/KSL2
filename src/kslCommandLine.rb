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
      @currentUser = KSLUsers::KSLUser.new(Process::UID.eid, ENV["USER"])
      @kpengine    = KSLPlugin::PluginEngine.new @currentUser
      @hostname = Socket.gethostname

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

      @embeddedCommands = ["exit", "sudo", "cd", "ksherb"]
      @pluginCommands   = @kpengine.kpstore.plugins.keys
      @commands         = @embeddedCommands + @pluginCommands
      puts "loaded plugins:"
      @kpengine.kpstore.showPlugins
    end

    #Todo : pipe implement
    def commandLine
      loop do
        @pluginCommands   = @kpengine.kpstore.plugins.keys
        @commands         = @embeddedCommands + @pluginCommands

        $stdin = STDIN
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

        inputLine = Readline.readline("\r\e[36m#{@currentUser.name}\e[0m\e[36m@#{@hostname}\e[0m \e[31m[KSL2]\e[0m \e[1m#{pathCompress(Dir.pwd)}\e[0m #{getPrompt}", true)
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

        commands.each do |command|
            #Embedded Functions
            inputLine = command
            inputLine.gsub!("~/", ENV["HOME"] + "/")

            redirectFlag = false
            if inputLine =~ /.*\s>(.*)/
              $stdout = File.open($1, "w")
              inputLine.gsub!(/\s?>.*/, "")
              redirectFlag = true
            end

            if inputLine =~ /exit/
              if @currentUser.exit
                return :exitKSL
              end
            elsif inputLine =~ /cd/
              args = inputLine.split
              if args[1].to_s.empty?
                args[1] = ENV["HOME"]
              end
              unless File.exist?(args[1])
                puts "no such file or directory: \'#{args[1]}\'"
              end
              Dir.chdir(args[1])
            elsif inputLine =~ /help/
              puts "commands:"
              @commands.each do |e|
                puts "  " + e.to_s
              end
            elsif inputLine =~ /sudo/
              @currentUser.sudo
            elsif inputLine =~ /^\.\D+$/
              inputLine = inputLine[1..inputLine.size-1]
              puts "system => #{inputLine}"
              system(inputLine)
            elsif inputLine =~ /sherb/
              pluginName = inputLine.split[1]
              print "=> "
              lines = ""
              STDIN.each_line do |input|
                print "=> "
                lines += input
              end
              pluginHash = {
                "command" => pluginName,
                "level" => 0,
                "script" => lines
              }
              @kpengine.kpstore.addPlugin @kpengine.kpl.loadByHash(pluginHash)
            else
              unless @kpengine.engine inputLine
                flag = false
                commands.each do |e|
                  if Trigram.compare(e, inputLine.split[0]) > 0
                    e = "\e[35m" +  e + "\e[0m"
                    puts "Did you mean \"#{e}\"?"
                    flag = true
                    break
                  end
                end

                if File.directory?(inputLine.split[0])
                  Dir.chdir(inputLine.split[0])
                  flag = true
                end

                unless flag
                  puts "\"#{inputLine.split[0]}\" is not a KSL2 Command"
                end
              end
            end

            if redirectFlag
              $stdout = STDOUT
            end
        end
      end
    end

    private
    def getPrompt
      if @currentUser.root?
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
