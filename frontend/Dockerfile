FROM busybox:1.35

RUN adduser -D stud
USER stud
WORKDIR /home/stud

COPY src/ .
COPY entrypoint.sh .

USER root
RUN chown -R stud:stud .
USER stud

EXPOSE 8000

ENTRYPOINT ["./entrypoint.sh"]
CMD ["httpd", "-f", "-v", "-p", "8000"]
