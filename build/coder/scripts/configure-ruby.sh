#######################################
# Ruby-specific Configuration
#######################################

#######################################
# Rails Server PID Cleanup
#######################################

# Remove potentially stale Rails server.pid file
if [ -f /code/tmp/pids/server.pid ]; then
	echo "INFO: Removing stale Rails server.pid file"
	rm -f /code/tmp/pids/server.pid
fi
