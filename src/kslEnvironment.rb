#encoding:utf-8
=begin
  KSLEnvironment

  The implementation of ksl environment values store.

  Copyright (C) 2015 alphaKAI http://alpha-kai-net.info
  The MIT License.
=end

module KSLEnvironment
  class KSLEnvironment
    def initialize
      @KSLENV = Hash.new
    end

    def envs
      return @KSLENV
    end

    def setEnv(key, value)
      @KSLENV[key] = value
    end

    def deleteEnv(key)
      @KSLENV.delete(key)
    end

    def getEnv(key)
      if @KSLENV.keys.include?(key)
        return @KSLENV[key]
      else
        #puts "[Error] - Undefined such a ENV : #{key}"
        return ""
      end
    end

    def replaceEnvs(line)
      return line.split.map do |e|
        r = e.scan(/\$\w+/)
        r.empty? ? e : self.getEnv(r[0])
      end.join(" ")
    end
  end
end
