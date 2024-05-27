FROM httpd:2.4

COPY ./src/ /usr/local/apache2/htdocs/
ARG IP=user3148951backend.us-east-1.elasticbeanstalk.com

RUN sed -i "s/localhost:8080/$IP/g" /usr/local/apache2/htdocs/js/script.js

EXPOSE 80
