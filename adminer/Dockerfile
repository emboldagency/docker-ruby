FROM adminer:latest

USER root

RUN apk add --no-cache git curl

COPY --chown=adminer:adminer --chmod=644 adminer-auto-login.php /var/www/html/plugins/adminer-auto-login.php

USER adminer
