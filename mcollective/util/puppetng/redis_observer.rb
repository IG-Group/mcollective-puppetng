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

module MCollective
module Util
module PuppetNG

require 'redis'

# This class hooks into the application with the following client.cfg options
# plugin.puppetng.observer_require = mcollective/util/puppetng/redis_observer
# plugin.puppetng.observer_class = MCollective::Util::PuppetNG::RedisObserver

# Information about each host is updated into its own key under
# run::{runid}::host::{hostname}
#
# Some metadata about the run is in run::{runid}::meta
#
# A sorted set at run::{runid}::activity can be used to find which keys
# hosts have updated.

class RedisObserver
  def initialize
    @config = MCollective::Config.instance

    @redis_host = @config.pluginconf.fetch("redis.host", "localhost")
    @redis_port = Integer(@config.pluginconf.fetch("redis.port", "6379"))
    @redis_db = Integer(@config.pluginconf.fetch("redis.db", "0"))
    @redis_pass = @config.pluginconf.fetch("redis.pass", nil)

    @redis = ::Redis.new(:host => @redis_host, :port => @redis_port, :db => @redis_db, :password => @redis_pass)
  end

  def on_complete(hosts, failures)
    meta_key = "#{basekey(hosts)}::meta"
    @redis.multi do 
      @redis.hmset(meta_key, :end_time, Time.now.to_i)
      @redis.hmset(meta_key, :n_failed, failures.length)
      @redis.hmset(meta_key, :n_success,  hosts.succeeded.length)
    end
  end

  def basekey(hosts)
    return "run::#{hosts.runid}"
  end

  def on_txn_start(serial)
	  @redis.multi
  end

  def on_txn_end(serial)
	  @redis.exec
  end

  def discovery(hosts, filters)
    activity_key = "#{basekey(hosts)}::activity"
    meta_key = "#{basekey(hosts)}::meta"

    @redis.mapped_hmset(meta_key, { :filters => JSON.dump(filters), :start_time => Time.now.to_i, :size => hosts.length })

    @redis.multi do 
      hosts.values.each do |h|
        @redis.zadd(activity_key, 0, h.hostname)
      end
      @redis.zadd("run::index", Time.now.to_i, hosts.runid)
    end
  end

  def host_for_redis(host)
    if host.latest.nil?
      output = {}
    else
      output = host.latest.clone
    end
    output["state"] = host.state
    output["local_error"] = host.local_error unless host.local_error.nil?
    output["serial"] = host.serial
    output.each_pair do |k,v|
      if v.is_a?(Hash) or v.is_a?(Array)
        output[k] = JSON.generate(v)
      end
    end
    output
  end

  def on_node_update(collection, host)
    basekey = "run::#{collection.runid}"
    hostkey = "#{basekey}::host::#{host.hostname}"

    @redis.del(hostkey)
    @redis.mapped_hmset(hostkey, host_for_redis(host))
    @redis.zadd("#{basekey}::activity", host.serial, host.hostname)
  end
end

end
end
end
