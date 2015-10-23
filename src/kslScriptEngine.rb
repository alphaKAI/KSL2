#encoding:utf-8
=begin
  KSLScriptEngine

  The implementation of ksl Shell Script.

  Copyright (C) 2015 alphaKAI http://alpha-kai-net.info
  The MIT License.
=end

module KSLScriptEngine
  class ScriptEngine
    attr_reader :blockTokenStack
    def initialize(kemachine, kslenv)
      @kemachine = kemachine
      @kslenv    = kslenv

      @blockTokenPairs = {
        "module" => "end",
        "class" => "end",
        "def" => "end",
        "do"  => "end",
        "{"   => "}"
      }

      @blockTokenPairs_reversed = {}
      @blockTokenPairs.each do |k, v|
        @blockTokenPairs_reversed[v] = k
      end

      @tokenPairs = {
        "|" => "|",
        "[" => "]",
        "(" => ")"
      }
      @tokenPairs_reversed ={}
      @tokenPairs.each do |k, v|
        @tokenPairs_reversed[v] = k
      end

      @tokenStack = Array.new
      @blockTokenStack = Array.new
    end

    def engine(inputLines)
      inputLine = inputLines.map do |line|
        cmdName = line.split[0]
        isKemEvent = false
        
        @kemachine.regexes.each do |ptn|
          if ptn =~ cmdName
            isKemEvent = true
            break
          end
        end

        if isKemEvent
          "@kemachine.execute(\"" + cmdName + "\" " + line.split[1..-1].join(" ") + ")"
        else
          line
        end
      end

      begin
        executeByRuby(inputLine.join(";"))
      rescue => e
        puts "[Exception -> KSLScriptEngine::ScriptEngine.engine] : #{e}"
        return false
      end
      return true
    end

    def executeByRuby(input)
      eval(input)
    end

    def executeByKEM(input)
      input = @kslenv.replaceEnvs(input)
      @kemachine.execute(input)
    end

    def checkInput(inputLine)
        inputLine.split("").each do |c|
          @tokenPairs.keys.each do |tk|
            if tk == c
              @tokenStack.push tk
              next
            end
          end
          @tokenPairs.each do |b, e|
            if c == e
              t = @tokenStack.pop
              unless t == b
                puts "[Error -> KSLScriptEngine::ScriptEngine.checkInput] syntax error"
                return false
              end
            end
          end
        end

      ["", " "].each do |spliter|
        inputLine.split(spliter).each do |c|
          @blockTokenPairs.keys.each do |tk|
            if tk == c
              @blockTokenStack.push tk
              next
            end
          end
          @blockTokenPairs.each do |b, e|
            if c == e
              if @blockTokenStack.empty?
                return true
              end
              t = @blockTokenStack.pop
              unless @blockTokenPairs[t] == c
                puts "[Error -> KSLScriptEngine::ScriptEngine.checkInput(btp)] syntax error"
                return false
              else
                return true
              end
            end
          end
        end
      end
    end
  end
end
