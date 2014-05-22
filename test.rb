#!/usr/bin/ruby

# Copyright IG Group
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# a simple test of the util code. starting a puppet run, reading the
# report out and displaying it.
 
$LOAD_PATH << "/usr/libexec/mcollective"
$LOAD_PATH << "/usr/lib/ruby/site_ruby/1.8/mcollective/vendor"

require 'load_json'
require 'logger'
require 'optparse'
require 'mcollective'
require 'mcollective/util/puppetng'

testid=`uuidgen`.chomp

include MCollective

@config = MCollective::Config.instance
@config.loadconfig("/etc/mcollective/server.cfg")
report_dir = @config.pluginconf.fetch("puppetng.report_dir", "/tmp")

puts "start test run #{testid}"

puppet_agent = Util::PuppetAgentMgr.manager(nil, "puppet")
registry = Util::PuppetNG::PuppetRunRegistry.new(puppet_agent, report_dir)
pr = Util::PuppetNG::ManagedPuppetRun.new(puppet_agent, testid)
pr.start

report = registry.load_from_disk(testid)
if report.nil?
  raise "no report found."
end

puts report.inspect

raise "report state not set to success" if report[:state] != :success

puts "OK"

exit 0
