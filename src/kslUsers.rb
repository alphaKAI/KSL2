#encoding:utf-8
=begin
  KSLUsers Module

  The implementation of user management system for KSL2.

  Copyright (C) 2015 alphaKAI http://alpha-kai-net.info
  The MIT License.
=end

require "digest/sha2"
require "io/console"
require "yaml"

module KSLUsers
=begin
  KSLUser Class
  The user system for KSL user.(This class is only user system. Not user management system.)
=end
  class KSLUser
    attr_reader :name
    def initialize(level, name)
      # Normal : 0, Root : 1
      @userLevel = level == 1 ? 1 : 0
      @name      = name
      @orgname   = @name
      @sudo      = false
      @config    = Hash.new

      loadUserConfig unless $WITHOUT_KSL_USER_CONFIG
    end

    def auth(message = "")
      puts message unless message.empty?

      print "Password: "
      input =  STDIN.noecho(&:gets).chomp
      puts ""
      if Digest::SHA256.hexdigest(input) == @config["password"]
        return true
      else
        return false
      end
    end

    def root?
      if @userLevel == 1
        return true
      else
        return false
      end
    end

    def sudo
      success = false
      
      3.times do
        if auth
          success = true
          break
        end
      end

      if(success)
        @userLevel = 1
        @sudo      = true
        @name     += "\e[35m[sudo]\e[0m"
      end
    end

    def exit
      if @sudo == true
        @userLevel = 0
        @sudo      = false
        @name = @orgname
        return false
      else
        return true
      end
    end

    private
    def loadUserConfig
      filepath = $srcPath + "/config/#{ENV["USER"]}.yaml"
      userExists = File.exists?(filepath)
      if userExists
        @config = YAML.load(File.read(filepath))
      else
        puts "------------------"
        puts "#Initial settings wizard"
        puts "Your setting file is yet to be created."
        @config["name"]     = @name
        puts "-password-"
        @config["password"] = Digest::SHA256.hexdigest(
          while true
            print "Your Password: => "
            p1 = STDIN.noecho(&:gets).chomp
            puts ""
            print "Confirm => "
            p2 = STDIN.noecho(&:gets).chomp
            puts ""
            if p1 == p2
              break p1
            else
              puts "Not confirmed. please retry."
            end
          end)
        puts "-HOME Directory-"
        print "Change your home directory(#{ENV["HOME"]})?(Only for KSL2) [Y/N]: "
        if STDIN.gets.chomp.downcase == "y"
          print "Please input your new home directory : "
          @config["home"] = STDIN.gets.chomp
        else
          @config["home"] = ENV["HOME"]
        end

        puts "Your setting file has been created."
        puts "You can edit the setting file anytime."
        puts "The file is located on #{File.expand_path($srcPath + "/config/" + ENV["USER"] + ".yaml")}"
        File.write($srcPath + "/config/" + ENV["USER"] + ".yaml", YAML.dump(@config))
        puts "------------------"
      end
    end
  end

=begin
  KSLUsers Class
  The user management System.
=end
  #Todo: Implement
  class KSLUsers

  end
end
