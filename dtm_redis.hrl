-record(config, {shell=false, buckets=1, monitors=1, iface=all, port=6379, backlog=20}).

-record(buckets, {bits=0, map}).
-record(monitors, {map}).
