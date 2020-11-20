FROM debian:10
RUN apt-get update && apt-get install -y nginx cron supervisor postgresql rsyslog wget sudo
RUN adduser --system public-udd-mirror
COPY webroot /var/www/html
RUN mkdir -p /var/www/html/logs && chown public-udd-mirror /var/www/html/logs
RUN touch --date=1970-01-01 /var/www/html/stamp && chown public-udd-mirror /var/www/html/stamp
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY rsyslog.conf /etc/rsyslog.d/stdout.conf
COPY crontab /etc/crontab
COPY scripts/update_udd.sh /usr/local/bin/update_udd.sh
COPY public-udd-mirror-sudoers.conf /etc/sudoers.d/public-udd-mirror-sudoers
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]