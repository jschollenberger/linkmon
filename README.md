# linkmon
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

**Link management utility for Allstar**

This utility was created to help automate connecting to, and disconnecting from, Allstar nodes. It is configurable to disconnect from a remote node based on a timer or inactivity based interval.

```
[09/29/2021 08:59:42] Monitoring temporary transceive link: 50420 - K2BR|146.745 (-) Repeater | Egg Harbor Twp., NJ
[09/29/2021 08:59:42] The link will automatically disconnect after 120 minutes at 10:59 OR after 3 cumulative minutes of inactivity.

[09/29/2021 08:59:42] Disconnecting existing outbound links... None found.
[09/29/2021 08:59:42] Establishing connection to: 50420...
[09/29/2021 08:59:49] Link Information: 50420 10.1.10.136 0 OUT 00:00:01.521 ESTABLISHED

[09/29/2021 08:59:50] Current TX time for Node 53209: 07h:18m:20s
[09/29/2021 08:59:50] Sleeping 60 seconds...
[09/29/2021 09:00:50] TX time increasing: 07h:19m:18s > 07h:18m:20s. Link Timer: 1 of 120 minutes. Sleeping 60 seconds...
[09/29/2021 09:01:51] TX time increasing: 07h:20m:07s > 07h:19m:18s. Link Timer: 2 of 120 minutes. Sleeping 60 seconds...
{...}
[09/29/2021 10:00:55] TX time increasing: 08h:14m:21s > 08h:14m:09s. Link Timer: 61 of 120 minutes. Sleeping 60 seconds...
[09/29/2021 10:01:56] TX time not increasing: 08h:14m:21s = 08h:14m:21s. 1 of 3 minute inactivity allowance.
[09/29/2021 10:02:57] TX time not increasing: 08h:14m:21s = 08h:14m:21s. 2 of 3 minute inactivity allowance.
[09/29/2021 10:03:57] TX time not increasing: 08h:14m:21s = 08h:14m:21s. Disconnecting link 50420.
[09/29/2021 10:03:59] Linkmon shutting down...
```

## Configuration

You can adjust the variables at the top of the script to meet your needs.

By default, it will poll Asterisk every 60 seconds, allow 3 cumlative minutes of inactivity before disconnecting the link, and make announcements on connect and disconnect.

```
# Total inactivity allowed in minutes (3 minute default)
INACTIVITY_ALLOWANCE=3

# Seconds to sleep between polling asterisk (1 minute default, other values untested)
SLEEP_TIME=60

# Play a global message before connecting, and after disconnecting, with information about the link (default 1)
ANNOUNCE_LINK=1

# Path to your asterisk binary
ASTERISK=/usr/sbin/asterisk

# Path to your allstar env file
ALLSTARENV=/usr/local/etc/allstar.env

# Path to astdb.txt
ASTDB=/var/log/asterisk/astdb.txt
```

For the link connect/disconnect announcements to work, you must have asterisk compatible audio files in `/etc/asterisk/local`.

You should generate at least two generic sound files, one for connecting, and one for disconnecting:
```
cat /var/lib/asterisk/sounds/node.gsm /var/lib/asterisk/sounds/connected.gsm > /etc/asterisk/local/node-connect.gsm
cat /var/lib/asterisk/sounds/node.gsm /var/lib/asterisk/sounds/disconnected.gsm > /etc/asterisk/local/node-disconnect.gsm
```
You can optionally have custom sounds for every link you plan to establish, named after the node ID and the action. 

For example, to have a custom message for node 29332, you would create `29332-connect.gsm` and `29332-disconnect.gsm` in `/etc/asterisk/local` and they would be played instead.

## Usage

Linkmon can accept 3 arguments and requires 2:

`linkmon.sh <node ID to connect to> <link time in minutes> <optional local node ID>`

For example, to connect to node 53209 for 60 minutes you would run: linkmon.sh 53209 60

If you have your local node ID in `/usr/local/etc/allstar.env` then the 3rd argument is not required.

You can invoke linkmon from command line, but most people will use cron.

For example, to connect to the Alaska Morning Net you would add this to your cron:

```
# -------- Alaska Net --------
# Start linkmon for Alaska Morning Net (every day at 13:00 for 3.5 hours)
59 12 * * * (sleep 40 && /etc/asterisk/local/linkmon/linkmon.sh 29332 210 >> /tmp/linkmon.log)
```

We start the cron 1 minute prior to the start of the net, then sleep for 40 seconds, which gives us 20 seconds to announce the connection and establish the link. This cron also logs to `/tmp/linkmon.log` so you can follow along with the output. If you use supermon, you can add a button to the UI which tails this file. 


## License
This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.
