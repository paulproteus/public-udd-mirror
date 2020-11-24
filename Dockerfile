FROM debian:10
RUN apt-get update && apt-get install -y nginx cron supervisor postgresql postgresql-11-debversion rsyslog wget sudo sysstat-
RUN adduser --system public-udd-mirror
COPY webroot /var/www/html
RUN mkdir -p /var/www/html/logs && chown public-udd-mirror /var/www/html/logs
RUN touch --date=1970-01-01 /var/www/html/stamp && chown public-udd-mirror /var/www/html/stamp
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY rsyslog.conf /etc/rsyslog.d/stdout.conf
COPY crontab /etc/crontab
COPY scripts/update_udd.sh /usr/local/bin/update_udd.sh
COPY public-udd-mirror-sudoers.conf /etc/sudoers.d/public-udd-mirror-sudoers
COPY postgreslisten.conf /etc/postgresql/11/main/conf.d/
COPY postgreseatmydata.conf /etc/postgresql/11/main/conf.d/
RUN echo 'host all udd-mirror 0.0.0.0/0 md5' >> /etc/postgresql/11/main/pg_hba.conf
RUN echo 'host all udd 0.0.0.0/0 md5' >> /etc/postgresql/11/main/pg_hba.conf
EXPOSE 80
EXPOSE 5432
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
