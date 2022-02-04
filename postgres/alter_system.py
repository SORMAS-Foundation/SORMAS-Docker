#!/usr/bin/env python3
"""
ALTER SYSTEM writes the given parameter setting to the postgresql.auto.conf file,
which is read in addition to postgresql.conf
"""
import sys
import os
import re
import psutil
import optparse

kB = 1024
MB = 1048576
GB = 1073741824
TB = 1099511627776

def read_options(program_args):
    parser = optparse.OptionParser(usage="usage: %prog [options]",
                                   version="0.0.1b",
                                   conflict_handler="resolve")

    parser.add_option('-i', '--input-config', dest="input_config", default=None,
                      help="Input configuration file")

    parser.add_option('-o', '--output-config', dest="output_config", default=None,
                      help="Output configuration file")

    parser.add_option('-t', '--tuning-parameters', dest="tuning_config", default=None,
                      help="Tuning parameter configuration file")

    options, args = parser.parse_args(program_args)
    return options, args, parser

def humanize(value):
  if isinstance(value, str) and not value.isdigit():
    return value
  v = int(value)
  val = int(v / TB)
  if val > 0:
    return str(val)+ "TB"
  val = int(v / GB)
  if val > 0:
    return str(val)+ "GB"
  val = int(v / MB)
  if val > 0:
    return str(val)+ "MB"
  val = int(v / kB)
  if val > 0:
    return str(val)+ "kB"
  return str(v)

def human_to_int(value):
  if "TB" in value:
    return TB * int(value.strip("TB"))
  if "GB" in value:
    return GB * int(value.strip("GB"))
  if "MB" in value:
    return MB * int(value.strip("MB"))
  if "kB" in value:
    return kB * int(value.strip("kB"))
  return int(value)

# Get memory limit
# returns amount of memory in bytes as int
def get_mem():
  # get memory numbers from host
  sysmem = psutil.virtual_memory().total
  # cgroup v2
  try:
      mem = open("/sys/fs/cgroup/memory.max").read().rstrip()
  except IOError:
      # cgroup v1
      try:
          mem = open("/sys/fs/cgroup/memory/memory.limit_in_bytes").read().rstrip()
      # no cgroup memory limits configured, assuming max
      except IOError:
          mem = "max"

  # max in cgroup v2, -1 in v1
  # if max or cgroup limit mem bigger than sysmem, use sysmem, else use cgroup mem limit
  return sysmem if mem in ("max", "-1") or int(mem) > sysmem else int(mem)

# Get CPU limit
# returns amount of CPUs as int
def get_cpu():
    # cgroup v2
    try:
        cpu_quota, cpu_period = open("/sys/fs/cgroup/cpu.max").read().rstrip().split()
    except IOError:
        # cgroup v1
        try:
            cpu_quota = open("/sys/fs/cgroup/cpu,cpuacct/cpu.cfs_quota_us").read().rstrip()
            cpu_period = open("/sys/fs/cgroup/cpu,cpuacct/cpu.cfs_period_us").read().rstrip()
        # no cgroup memory limits configured, assuming max
        except IOError:
            cpu_quota = "max"

    # max in cgroup v2, -1 in v1
    # if max, use system cpu count, else calculate cpu limits
    return psutil.cpu_count() if cpu_quota in ("max", "-1") else int(cpu_quota) // int(cpu_period) + 1

def read_config_file(filename):
  config = {}
  for i, line in enumerate(open(filename)):
      line = line.rstrip('\n')
      comment_index = line.find('#')
      equal_index = line.find('=')
      if equal_index >= 0 and ( comment_index > equal_index or comment_index == -1):
        name, value = line.split('=', 1)
        name = name.strip()
        value = re.sub(r'#.*$', '', value).strip()
        config[name] = value
  return config

def get_tuning_values(config, filename):
  mem = get_mem()
  cpu = get_cpu()
  values = {}
  for i, line in enumerate(open(filename)):
      line = line.rstrip('\n')
      comment_index = line.find('#')
      equal_index = line.find('=')
      if equal_index >= 0 and ( comment_index > equal_index or comment_index == -1):
        name, value = line.split('=', 1)
        name = name.strip()
        value = re.sub(r'#.*$', '', value).strip()
        # are there any used variables in the formula referring to config variables from
        # the config file? e.g.: max_connections
        # loop over all elements of formula
        for v in value.split():
          # element is a variable from the config file?
          if v in config:
            # assign value from config file to variable
            exec( v + " = int(config['" + v + "'])" )
        # shared_buffers = mem / 4 => values['shared_buffers'] = int(men/4)
        try:
          exec( "values['" + name + "'] = int(" + value + ")" )
        except ValueError:
          exec( "values['" + name + "'] = " + value )

  if "maintenance_work_mem" in values and values['maintenance_work_mem'] > int( 2 * GB ):
      values['maintenance_work_mem'] = int( 2 * GB )
  if "wal_buffers" in values and values['wal_buffers'] > int( 16 * MB ):
      values['wal_buffers'] =int( 16 * MB )
  # set max_connections depending on JDBC_MAXPOOLSIZE
  pool_size = 0
  try:
    pool_size = int( os.environ['DB_JDBC_MAXPOOLSIZE'] )
  except:
    pool_size = 128
  if pool_size < 128:
    pool_size = 128
  values['max_connections'] = pool_size * 2 + 14
  return values

def alter_system(filename, config, values):
  auto = open(filename, 'w')
  for name, value in values.items():
    if name in ['max_connections']:
      auto.write(name + " = '" + str(value) + "'\n")
    else:
      auto.write(name + " = '" + humanize(value) + "'\n")
  auto.close()

def main(program_args):
  options, args, parser = read_options(program_args)
  config = read_config_file(options.input_config)
  values = get_tuning_values(config, options.tuning_config)
  alter_system(options.output_config, config, values)

if __name__ == '__main__':
  sys.exit(main(sys.argv))
