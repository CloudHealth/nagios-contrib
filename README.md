nagios-contrib
==============

Cloudhealth specific Nagios scripts

Performance Data
----------------

Cloudhealth's API has the ability to take in the raw service performance data and parse it without you needing to convert it into a metric first.

### Setup

1. Edit nagios.cfg to enable capturing performance data, and then sending it to our script every 15min. Note the changes in the template to change the delimiter, as well as the host entry. We use $HOSTADDRESS$ since it will best match the attributes we capture from each AWS instance.

```
process_performance_data=1
service_perfdata_file=/tmp/service-perfdata
service_perfdata_file_template=$TIMET$|$HOSTADDRESS$|$SERVICEDESC$|$SERVICEEXECUTIONTIME$|$SERVICELATENCY$|$SERVICEOUTPUT$|$SERVICEPERFDATA$
service_perfdata_file_processing_interval=900
service_perfdata_file_processing_command=process-service-perfdata-file
```

2. Add `process_perf_data 1` to each service definition you want to send to the API

``` 
define service {
  service_description all_disks
  hostgroup_name webserver
  check_command check_all_disks
  use default-service
  process_perf_data 1
}
```

3. Create the `process-service-perfdata-file` command. This will move the existing perfdata file to a temp file every `service_perfdata_file_processing_interval` seconds, and then send it to our customer script. The "-d" flag tells the script to delete the file when done.

```
define command {
        command_name process-service-perfdata-file
        command_line mv /tmp/service-perfdata /tmp/service-perfdata.$TIMET$ && /usr/lib/nagios/plugins/upload_perfdata_to_cloudhealth.rb -f /tmp/service-perfdata.$TIMET$ -d
}
```


