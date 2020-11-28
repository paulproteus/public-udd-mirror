FROM debian:10
RUN apt-get update && apt-get install -y nginx cron supervisor postgresql postgresql-11-debversion rsyslog wget sudo logrotate sysstat-
RUN adduser --system udd-mirror
COPY webroot /var/www/html
RUN mkdir -p /var/www/html/logs && chown udd-mirror /var/www/html/logs
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY rsyslog.conf /etc/rsyslog.conf
COPY logrotate.conf /etc/logrotate.conf
COPY crontab /etc/crontab
COPY scripts/update_udd.sh /usr/local/bin/update_udd.sh
COPY udd-mirror-sudoers.conf /etc/sudoers.d/udd-mirror-sudoers
COPY postgresql-udd-mirror.conf /etc/postgresql/11/main/conf.d/
RUN echo 'host all udd-mirror 0.0.0.0/0 md5' >> /etc/postgresql/11/main/pg_hba.conf
RUN echo 'host all udd 0.0.0.0/0 md5' >> /etc/postgresql/11/main/pg_hba.conf
RUN echo 'host all public-udd-mirror 0.0.0.0/0 md5' >> /etc/postgresql/11/main/pg_hba.conf
EXPOSE 80
EXPOSE 5432
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
