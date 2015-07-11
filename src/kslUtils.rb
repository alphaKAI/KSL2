#encoding:utf-8
=begin
  KSLUtils Module

  Copyright (C) 2015 alphaKAI http://alpha-kai-net.info
  The MIT License.
=end
module KSLUtils
  def pathCompress(path)
    path.gsub!(ENV["HOME"], "~") if path =~ /#{ENV["HOME"]}/
    return path
  end

  def match(str, pattern)
    p_length = pattern.length
    s_lebgth = str.length
    count    = 0

    s_lebgth.times do |i|
      tmp_s = []
      p_length.times do |j|
        tmp_s[j] = str[i + j]
      end
      if tmp_s.join == pattern
        count+=1
      end
    end

    return count
  end
end
