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
      @suMode    = false
      @config    = Hash.new
      @configFilePath = $srcPath + "/config/#{@name}.yaml"

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

    def home
      return @config["home"]
    end

    def aliases
      _aliases = @config["aliases"]
      if _aliases
        return _aliases
      else
        return Hash.new
      end
    end

    def addAlias(aliasHash)
      @config["aliases"][aliasHash[:contracted]] = aliasHash[:expanded]
    end

    def unalias(aliasName)
      @config["aliases"].delete(aliasName)
    end

    def saveConfig
      File.write(@configFilePath, YAML.dump(@config))
    end

    def suMode
      success = false
      
      # try limit
      3.times do
        if auth
          success = true
          break
        end
      end

      if(success)
        @userLevel = 1
        @suMode    = true
        @name     += "\e[35m[suMode]\e[0m"
      end
    end

    def exit
      if @suMode == true
        @userLevel = 0
        @suMode    = false
        @name = @orgname
        return false
      else
        return true
      end
    end

    def delete
      if auth("Please input password for #{@name}")
        File.delete @configFilePath
        puts "Your settings file has been removed"
        puts " => Exit"
        exit
      end
    end

    private
    def loadUserConfig
      userExists = File.exists?(@configFilePath)
      if userExists
        @config = YAML.load(File.read(@configFilePath))
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

        @config["aliases"] = Hash.new

        puts "Your setting file has been created."
        puts "You can edit the setting file anytime."
        puts "The file is located on #{File.expand_path(@configFilePath)}"
        saveConfig
        puts "------------------"
      end
    end
  end

=begin
  KSLUsers Class
  The user management System.
=end
  class KSLUsers
    attr_reader :currentUser, :nestedLogin
    def initialize(owner = nil)
      @users = {}
      @currentUser = nil
      @prevUser    = []
      @nestedLogin = false

      if owner
        @users[owner.name] = owner
        @currentUser = owner
      end

      @usersFileDir = $srcPath + "/config/"
      loadUsers
    end

    def users
      return @users.keys
    end

    def userExists?(userName)
      return users.include?(userName)
    end

    def addUser(userName)
      unless userExists?(userName)
        @users[userName] = KSLUser.new(0, userName)
        puts "[add user success] : User name \"#{userName}\""
      else
        puts "[add user fail] : User name \"#{userName}\" is alerady exists."
      end
    end

    def removeUser(userName)
      if userExists?(userName)
        print "Really delete \"#{userName}\"? [Y/N] : "

        if STDIN.gets.chomp.downcase == "y"
          if @users[userName].delete
            @users.delete(userName)
          end
        end
      end
    end

    def login(userName)
      unless userExists?(userName)
        puts "User \"#{userName}\" is not exists"
        return false
      else
        if @users[userName].auth("Please input password for #{userName}")
          @prevUser.push(@currentUser)
          @nestedLogin = true
          @currentUser = KSLUser.new(0, userName)
          @users[@currentUser.name] = @currentUser
          return true
        else
          puts "[login failed] : authorization failed"
          return false
        end
      end
    end

    def logout
      @currentUser = @prevUser.pop
      if @prevUser.empty?
        @nestedLogin = false
      end
    end

    def exit
      if @currentUser.exit
        return true
      elsif nestedLogin
        logout
        return false
      else
        return false
      end
    end

    private
    def loadUsers
      Dir.entries(@usersFileDir).each do |e|
        next if e == "." || e == ".."
        unless userExists?(e)
          e = File.basename(e, ".yaml")
          @users[e] = KSLUser.new(0, e)
        end
      end
    end
  end
end
