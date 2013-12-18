#!/usr/bin/env ruby

require 'optparse'
require 'json'
require 'time'
require 'uri'
require 'net/http'
require 'net/https'

def send_metric hostname, metric_name, value, units, ts, dimension
  metric_data = {
    :hostname => hostname,
    :namespace => 'CloudHealth/Nagios',
    :metric_data => [
      { :metric_name => metric_name,
        :value       => value,
        :unit        => units,
        :timestamp   => Time.at(ts.to_i).iso8601,
        :dimensions  => dimension
      },
    ]
  }

  uri = URI('https://api.cloudhealthtech.com/v1/host/metrics')
  req = Net::HTTP::Post.new(uri.request_uri)
  req.body = JSON.generate(metric_data)
  req.content_type = 'application/json'
  req.use_ssl = true
  req.verify_mode = OpenSSL::SSL::VERIFY_NONE
  req['Access-Token'] = INSERT YOUR API KEY
  res = Net::HTTP.start(uri.hostname, uri.port) {|http|
    response = http.request(req)
    case response
      when Net::HTTPSuccess then

      when Net::HTTPBadRequest
        $strerr.puts "ERROR"
      else
        $strerr.puts "STATUS CODE: #{response.code}"
    end
  }
end

$verbose = false

OptionParser.new do |o|
  o.on('-v') { $verbose = true }
  o.on('-f FILENAME') { |filename| $filename = filename }
  o.on('-h') { puts o; exit }
  o.parse!
end

sizes = { 'KB' => 1024, 'MB' => 1024*1024, 'GB' => 1024*1024*1024, 'TB' => 1024*1024*1024*1024, 'PB' => 1024*1024*1024*1024*1024}

File.open($filename, 'r') do |infile|
  while (line = infile.gets)
    parts = line.chomp.split('|')
    next if parts.length < 5

    #service_perfdata_file_template=$TIMET$|$HOSTADDRESS$|$SERVICEDESC$|$SERVICEOUTPUT$|$SERVICEPERFDATA$|$SERVICEEXECUTIONTIME$|$SERVICELATENCY$|$LASTSERVICECHECK$|$HOSTGROUPNAMES$
    ts         = parts[0] # 1386612532
    hostname   = parts[1] # localhost
    service    = parts[2] # CPU Stats
    srv_output = parts[3] # CPU OK : idle 99.80%
    perf_data  = parts[4] # user=0.00% system=0.20% iowait=0.00% idle=99.80%;90;100

    case service
      when 'Root Partition'
        metric_name = 'FileSystemUsed'
        dimension = [{:name => 'mount', :value => '/'}]
        usage = perf_data.split(';')[0].split('=')[1] # /=1337MB;7385;8308;0;9232
        groups = usage.match(/^([0-9]+)(KB|MB|GB|TB|PB)?$/i)

        unless groups.length == 3
          # TODO: output warning
          next
        end

        value = groups[1].to_i * sizes[groups[2].upcase]
        units = 'Bytes'

        groups = srv_output.match(/.*free\ space\:\ \/\ ([\d]{1,})\ (KB|MB|GB|TB)+\ */i)
        if groups.length == 3
          dimension << {:name => 'size', :value => groups[1].to_i * sizes[groups[2].upcase]}
        end

        send_metric hostname, metric_name, value, units, ts, dimension

      when 'all_disks'
        #1386882706|domU-12-31-39-0B-66-71|all_disks|0.079|0.131|DISK OK - free space: / 5266 MB (55% inode=70%): /dev 3716 MB (99% inode=99%): /run 1489 MB (99% inode=99%): /run/lock 5 MB (100% inode=99%): /run/shm 3725 MB (99% inode=99%): /run/user 100 MB (100% inode=99%): /mnt/ephemeral-xvdb 417872 MB (97% inode=99%): /mnt/ephemeral-xvdc 428770 MB (99% inode=99%):|/=4301MB;9272;9575;0;10079 /dev=0MB;3418;3530;0;3716 /run=0MB;1370;1415;0;1490 /run/lock=0MB;4;4;0;5 /run/shm=0MB;3427;3538;0;3725 /run/user=0MB;92;95;0;100 /mnt/ephemeral-xvdb=11960MB;395446;408341;0;429833 /mnt/ephemeral-xvdc=1062MB;395446;408341;0;429833
        next unless srv_output.start_with?('DISK OK')

        srv_groups = srv_output.scan(/(([^\ ]+)\ ([0-9]+)\ (KB|MB|GB)\ \([\d]{1,3}%\ inode=[\d]{1,3}%\):\ ?)/i)

        metric_name = 'FileSystemUsed'
        units = 'Bytes'
        groups = perf_data.scan(/(([^=]*)=([0-9]+)(KB|MB|GB|TB|PB);[\d]+;[\d]+;[\d]+;[\d]+\ ?)/i)
        groups.each_index {|i|
          g = groups[i]
          next unless g.length == 4
          next unless g[1] == '/' || g[1].start_with?('/mnt')
          dimension = [{:name => 'mount', :value => g[1]}]
          value = g[2].to_i * sizes[g[3].upcase]

          if srv_groups[i][1] == g[1]
            dimension << {:name => 'size', :value => srv_groups[i][2].to_i * sizes[srv_groups[i][3].upcase]}
          end

          send_metric hostname, metric_name, value, units, ts, dimension
        }
      else
        next
    end

  end
end
