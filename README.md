nagios-contrib
==============

CloudHealth specific Nagios scripts.

Uploading Performance Data
----------------

CloudHealth's Platform API has the ability to take in the raw service performance data and parse it without you needing to convert it into a metric first.

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

4. Add `upload_perfdata_to_cloudhealth.rb` to your nagios plugins folder, and `chmod 755` it.
5. Edit `upload_perfdata_to_cloudhealth.rb` and change the Access-Token to the value you got from the CHT Portal.
6. Restart nagios for the changes to take effect: `/etc/init.d/nagios restart`

### Testing the setup

1. You can remove the "-d" flag (and restart nagios) so that the files are not deleted. Also, prior to restarting, you can change the interval from 900 to something like 60 to get the files generated more frequently.
2. Double check that the files contain the services you enabled. If the service runs less frequently than our interval, then some of the perfdata files might be empty.
3. Manually run the script: `/usr/lib/nagios/plugins/upload_perfdata_to_cloudhealth.rb -f /tmp/service-perfdata.1387301134` and make sure there are no errors outputted.


