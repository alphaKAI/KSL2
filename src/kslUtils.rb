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
end
