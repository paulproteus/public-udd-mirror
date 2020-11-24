udd-mirror
=================

Information and bug tracker for public (unofficial) instance of Ultimate Debian Database

See https://udd-mirror.debian.net/ for more information.

Development
===========

Use `git clone` to download the code from this repository.

Run the app with: `docker run -p 8000:80 $(docker build -q .)` This will start the app
and immediately download a snapshot of UDD. Logs will be printed to stdio. You can
access the public website at http://localhost:8000/.

The app will write files into the container, including keeping its Postgres data up-to-date.

If you change the Dockerfile or other files, stop and start the app with the above command.
It will automatically rebuild as needed.

This permits developing the environment from macOS, Linux, Windows, or anywhere else that Docker is available.

Cleanup
=======

You can remove old versions of the container that have not been used in the last 24 hours by
running the following.

```
docker container prune --filter "until=24h"
```

You can remove the disk space used by previous image builds by running the following.

```
docker image prune -a
```

Implementation details
======================

This repositority creates a Docker container that periodically checks for a snapshot of the Ultimate Debian Database and loads it into Postgres for public read-only use. At launch, it checks for a fresh snapshot. It prints logs to the the Docker stdout.

By default, the container stores all data within the container. In development, it's appropriate to delete old instances to free up disk space. In production, we use Docker volumes (effectively bind-mounted directories) to retain the data even if the container is rebuilt or restarted.

The container starts a few services to manage the mirror. nginx, cron, rsyslogd, and postgres are managed by supervisord. The use of rsyslogd permits programs within the container to log to the Docker stdout.

Debugging
=========

The container prints a hostname as part of the output of most log lines. This can be used as a container ID for `docker exec`. If the hostname is 84256d2a6c4b, the following provides a root shell within the container.

```
docker exec -it 84256d2a6c4b /bin/bash
```

Production
==========

Create a volume to store Postgres data. This allows data to persist if the container is restarted or rebuilt.

```
docker volume create udd-mirror-postgres
docker volume create udd-mirror-logs
```

Create a Docker network so that 0.0.0.0 on the container points to a single IP address on the outer machine.

```
docker network create --subnet=172.18.0.0/16 udd-mirror-network
```

Run the container, exposing port 5432 globally.

```
docker build .
docker run -p 0.0.0.0:5432:5432 --net udd-mirror-network --mount source=udd-mirror-postgres,target=/var/lib/postgresql --mount source=udd-mirror-logs,target=/var/www/html/logs --ip 172.18.0.2 $(docker build -q .)
```

Validate that the container is running a Postgres instance with some data.

```
$ echo 'select count(*) from upload_history;' | psql "postgresql://udd:udd@172.18.0.2/udd"
 count
--------
 699516
(1 row)
```

Set up systemd to update and start the container at system boot. Create `/etc/systemd/system/udd-mirror.service` with these contents and run `sudo systemctl enable udd-mirror`.

```
[Unit]
Description=UDD mirror
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
User=udd-mirror
ExecStart=/bin/bash -c 'cd /srv/udd-mirror && git pull && docker build . && docker run -p 0.0.0.0:5432:5432 --net udd-mirror-network --mount source=udd-mirror-postgres,target=/var/lib/postgresql --mount source=udd-mirror-logs,target=/var/www/html/logs --ip 172.18.0.2 $(docker build -q .)'

[Install]
WantedBy=multi-user.target
```

Set up nginx or another reverse proxy to forward HTTP/HTTPS to the container.

Deploying new versions to production
====================================

If everything is set up per the previous suggestions, once new code is in this GitHub repository,
you can ssh to the production host and run:

```
sudo systemctl stop udd-mirror
sudo systemctl start udd-mirror
sudo journalctl -u udd-mirror -f
```
