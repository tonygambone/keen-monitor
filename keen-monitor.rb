#!/usr/bin/env ruby

# environment vars
require 'dotenv'
Dotenv.load

# async publish setup
require 'em-http-request'
Thread.new { EventMachine.run }

def loop
  begin
    require 'keen'
    while true do
      values = {
        ENV['KEEN_CPU_PROPERTY'] => get_cpu_usage,
        ENV['KEEN_MEM_PROPERTY'] => get_mem_usage
      }
      req = Keen.publish_async(ENV['KEEN_COLLECTION_NAME'], values)
      req.errback { puts "Publish error!" }
      req.callback { |r| puts "#{ENV['KEEN_COLLECTION_NAME']}: #{values}" }
      sleep ENV['SUBMIT_INTERVAL_SECS'].to_i
    end
  rescue SystemExit, Interrupt
    EventMachine.stop
  end
end

def get_cpu_usage
  # get first line of /proc/stat
  f = File.new('/proc/stat', 'r')
  line = f.gets
  f.close

  vals = line.split
  vals.shift # remove 'cpu'
  vals.map! { |x| x.to_i }

  if $lastvals
    delta = [vals,$lastvals].transpose.map { |x| x.reduce(:-) }
    idle = delta[3] / delta.reduce(:+).to_f
    $lastvals = vals
    (1 - idle).round(2)
  else
    $lastvals = vals
    sleep 1
    get_cpu_usage
  end
end

def get_mem_usage
  # read first two lines of /proc/meminfo
  f = File.new('/proc/meminfo', 'r')
  memtotal = f.gets.split[1].to_f
  memfree = f.gets.split[1].to_i
  f.close

  (1 - memfree / memtotal).round(2)
end

loop
puts "Done!"
