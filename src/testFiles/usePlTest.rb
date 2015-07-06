#encoding:utf-8
$WITHOUT_KSL_USER_CONFIG = true

require_relative "../kslPlugin.rb"
require_relative "../kslUsers.rb"

user = KSLUsers::KSLUser.new(Process::UID.eid, ENV["USER"])
engine = KSLPlugin::PluginEngine.new user
engine.kpstore.addPlugin engine.kpl.load("sample.yaml")
engine.kpstore.addPlugin engine.kpl.load("sample2.yaml")
engine.kpstore.addPlugin engine.kpl.load("sample3.yaml")

engine.engine "commandName alphaKAI 17"
puts "root test"
engine.engine "testCommand"
engine.engine "optTest -a"
