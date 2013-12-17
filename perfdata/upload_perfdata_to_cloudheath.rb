#!/usr/bin/env ruby

require 'optparse'
require 'json'
require 'time'
require 'uri'
require 'net/http'
require 'net/https'

def send_perfdata(hostname, ts, service, output, perfdata)

  payload = {
    'hostname'  => hostname,
    'timestamp' => Time.at(ts.to_i).iso8601,
    'service'   => service,
    'output'    => output,
    'perfdata'  => perfdata
  }

  uri = URI('https://api.cloudhealthtech.com/v1/ingress/nagios')

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  req = Net::HTTP::Post.new(uri.request_uri)
  req.body = JSON.generate(payload)
  req.content_type = 'application/json'
  req['Access-Token'] = INSERT YOUR API KEY

  response = http.request(req)

  case response
    when Net::HTTPSuccess

    when Net::HTTPBadRequest
      $strerr.puts "ERROR: #{response.body}"
    else
      $strerr.puts "STATUS CODE: #{response.code}"
  end

rescue => e
  puts e.message
end

$verbose = false
$delete_file = false

OptionParser.new do |o|
  o.on('-v') { $verbose = true }
  o.on('-d') { $delete_file = true }
  o.on('-f FILENAME') { |filename| $filename = filename }
  o.on('-h') { puts o; exit }
  o.parse!
end

begin
  File.open($filename, 'r') do |infile|
    while (line = infile.gets)
      parts = line.chomp.split('|')
      next unless parts.length == 7

      #service_perfdata_file_template=$TIMET$|$HOSTADDRESS$|$SERVICEDESC$|$SERVICEEXECUTIONTIME$|$SERVICELATENCY$|$SERVICEOUTPUT$|$SERVICEPERFDATA$
      #1386612532|127.0.0.1|CPU Stats|5.032|0.160|CPU OK : idle 99.80%|user=0.00% system=0.20% iowait=0.00% idle=99.80%;90;100
      ts         = parts[0] # 1386612532
      hostname   = parts[1] # localhost
      service    = parts[2] # CPU Stats
      runtime    = parts[3] # 5.032
      latency    = parts[4] # 0.160
      srv_output = parts[5] # CPU OK : idle 99.80%
      perf_data  = parts[6] # user=0.00% system=0.20% iowait=0.00% idle=99.80%;90;100

      # If not using $HOSTADDRESS$ in the perfdata file:
      #hostname = Socket.gethostbyname(hostname).first

      send_perfdata hostname, ts, service, srv_output, perf_data
    end
  end
rescue => e
  puts e.message
ensure
  if $delete_file
    File.unlink($filename) rescue nil
  end
end
