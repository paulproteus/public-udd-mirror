FROM debian:10
RUN apt-get update && apt-get install -y nginx cron supervisor postgresql rsyslog
COPY webroot /var/www/html
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY rsyslog.conf /etc/rsyslog.d/stdout.conf
COPY crontab /etc/crontab
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
