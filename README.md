# mcollective-puppetng

mcollective-puppetng is an mcollective agent and application for running
puppet on many systems.

It uses a small subset of code from the puppetlabs puppet agent, but is
otherwise a substantial rewrite with an emphasis on reliability, detecting and
handling failures, and reporting back the outcome of puppet runs. Many of the
configurables the puppetlabs agent did are not available in this yet, but
noop is.

Usually, it will report the errors that you would see on the puppet console.

With the original agent, our experience was that it was quite hard to know for
certain the run was successful on all systems. 

## License

Apache 2.0, see 'LICENSE' file.

## Dependencies

 * puppet
 * mcollective
 * mcollective-puppet-common - https://github.com/puppetlabs/puppetlabs-mcollective

## Components

### The application

The application coordinates the puppet runs across many agents.

 * util/puppetng/colorize.rb - for colorizing the output
 * application/puppetng.rb
 * It requires the agent DDL

example command:

```
mco puppetng run --concurrency 50
```

You can optionally setup an observer class using config. Included is an example
redis observer, which logs activity out to redis as it happens. We created a
web view which updates along with the console application (this is not included).

```
plugin.puppetng.observer_require = mcollective/util/puppetng/redis_observer
plugin.puppetng.observer_class = MCollective::Util::PuppetNG::RedisObserver
```

### The agent

The mcollective agent has two functions, run and check_run. When the run
function is called, a unique ID 'runid' is passed (the same for all nodes in a
run), which can then be provided to the check_run to get the status of it.

The puppet run is monitored by a daemon process backgrounded by the agent.
It monitors the puppet state directories, and when it detects change in
progress it writes the state to a JSON file (under /tmp by default). check_run
mostly just serves up this file.

 * /usr/libexec/mcollective/mcollective/agent/puppetng.rb
     starts the daemon or reads reports (using util/ code).
 * /usr/libexec/mcollective/mcollective/agent/puppetng.ddl
     DDL for the agent. See for available inputs and outputs.
 * util/puppetng/managed_puppet_run.rb - code for launching and monitoring a run
 * util/puppetng/puppet_run_registry.rb - for reading JSON reports from disk.
 * /usr/local/sbin/puppetng_agent - a daemon which just passes arguments and
     backgrounds the managed_puppet_run.rb code.

## Configuration

Most timeouts and paths used are configurable.

### Agent configurables (for server.cfg):

```
puppetng.timeout
  default: 60 * 20 (20 minutes)
  description: how long before a run times out.

puppetng.apply_wait_max
  default: 45 (seconds)
  description: when signalled, how long to wait for the daemon to start applying.

puppetng.report_wait_max
  default: 120 (seconds)
  description: after run completes, how long to wait for report to be written.

puppetng.expired_execution_retries
  default: 1
  description: if an "execution expired" error is encountered, how many times
    to retry.

puppetng.report_dir
  default: /tmp
  description: where to read and write JSON reports from.

puppetng.max_summary_failures
  default: 6
  description: how many failures to allow when reading a summary. (sometimes
    puppet seems to write "false" for a short time).

puppetng.max_report_failures
  default: 10
  description: how many failures to allow when reading a report. (sometimes
    puppet seems to write "false" for a short time).

puppetng.puppet_path
  default: /usr/bin/puppet
  description: path to puppet when running in foreground.

puppetng.agent_path
  default: /usr/local/sbin/puppetng_agent
  description: where is the puppetng_agent daemon installed.
```

### Client application configurables (for client.yml):

```
puppetng.display_progress_hosts_max
  default: 10
  description: show up to this number of hostnames when peridically
    showing where is in progress.

puppetng.display_progress_interval 
  default: 90 (seconds)
  description: how often to show in progress hosts. -1 to disable.

puppetng.display_progress_hosts_preview
  default: 4
  description: if in progress is > display_progress_hosts_max, show this
    many as a preview.

puppetng.exit_if_exceed_concurrency
  default: 100
  description: if greater than this number of hosts are discovered, don't start
    without --concurrency argument (to prevent overloading puppetmaster).

puppetng.ticks_before_unresponsive
  default: 3
  description: number of checks which need to fail to be considered unresponsive

puppetng.time_before_unresponsive
  default: 30
  description: time without check response from a node to be considered unresponsive
```

### For the optional redis observer:

```
redis.host
  default: localhost

redis.port
  default: 6379

redis.db
  default: 0

redis.pass:
  default: none
```
