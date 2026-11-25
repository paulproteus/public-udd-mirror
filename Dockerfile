FROM debian:trixie
RUN apt-get update && apt-get install -y nginx libjs-jquery cron supervisor postgresql postgresql-17-debversion rsyslog wget sudo logrotate certbot openssl sysstat-
RUN adduser --system udd-mirror
COPY webroot /var/www/html
RUN mkdir -p /var/www/html/logs && chown udd-mirror /var/www/html/logs
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY rsyslog.conf /etc/rsyslog.conf
COPY logrotate.conf /etc/logrotate.conf
COPY crontab /etc/crontab
COPY scripts/update_udd.sh /usr/local/bin/update_udd.sh
COPY scripts/renew_cert.sh scripts/install_pg_cert.sh scripts/start_postgres.sh /usr/local/bin/
COPY udd-mirror-sudoers.conf /etc/sudoers.d/udd-mirror-sudoers
COPY postgresql-udd-mirror.conf /etc/postgresql/17/main/conf.d/
# Postgres starts with the self-signed certificate from the ssl-cert package,
# install_pg_cert.sh replaces it with the one from Let's Encrypt.
RUN install -d -o postgres -g postgres -m 0700 /etc/postgresql/17/main/tls \
 && install -o postgres -g postgres -m 0644 /etc/ssl/certs/ssl-cert-snakeoil.pem /etc/postgresql/17/main/tls/server.crt \
 && install -o postgres -g postgres -m 0600 /etc/ssl/private/ssl-cert-snakeoil.key /etc/postgresql/17/main/tls/server.key
RUN echo 'host all udd-mirror 0.0.0.0/0 md5' >> /etc/postgresql/17/main/pg_hba.conf
RUN echo 'host all public-udd-mirror 0.0.0.0/0 md5' >> /etc/postgresql/17/main/pg_hba.conf
EXPOSE 80
EXPOSE 5432
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
