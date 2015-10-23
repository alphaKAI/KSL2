#encoding:utf-8
=begin
  KSLExecuteMachine Module

  The implementation of KSL Function Caller

  Copyright (C) 2015 alphaKAI http://alpha-kai-net.info
  The MIT License.
=end

$KEM_DEBUG = false

module KSLExecuteMachine
  class ExecuteMachine
    attr_reader :regexes

    def initialize
      @behaviorDefinedHash = Hash.new
      @regexes = Array.new
    end

    def eventExists?(eventName)
      return @behaviorDefinedHash.keys.include?(eventName)
    end

    def registerEvent(eventName, behaviorHash)
      @behaviorDefinedHash[eventName] = {
        :pattern => behaviorHash[:pattern],
        :lambda  => behaviorHash[:lambda]
      }
      @regexes << behaviorHash[:pattern]
    end

    def registerEventsByHash(behaviorsHash)
      behaviorsHash.each do |name, hash|
        registerEvent(name, hash)
      end
    end

    def deleteEvent(eventName)
      unless eventExists?(eventName)
        return false
      else
        @behaviorDefinedHash.delete eventName
      end
    end

    def execute(inputLine)
      if $KEM_DEBUG
        puts "-> KSLExecuteMachine::ExecuteMachine.execute"
        puts "[KEM::EM.execute] -> inputLine : #{inputLine}"
        puts "[KEM::EM.execute] -> @behaviorDefinedHash : #{@behaviorDefinedHash}"
      end

      arguments = []
      eventName = nil

      @behaviorDefinedHash.each do |name, value|
        puts "\e[32m REGEX -> #{value[:pattern]} \e[0m" if $KEM_DEBUG

        if value[:pattern] != nil && inputLine =~ value[:pattern]
          if $KEM_DEBUG
            puts name
          end
          eventName = name
          break
        end
      end

      #Todo : implement argument parser
      arguments = inputLine.split
      eventName = :default if eventName == nil

      puts "[KEM::EM.execute] -> eventName : #{eventName}" if $KEM_DEBUG
      return @behaviorDefinedHash[eventName][:lambda].call(arguments, inputLine)
    end
  end
end
