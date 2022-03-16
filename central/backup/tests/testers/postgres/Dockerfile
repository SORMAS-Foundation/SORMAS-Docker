FROM postgres:13.4

COPY res /res
RUN chmod a+x /res/*.sh
ENTRYPOINT [ "/res/entrypoint.sh" ]
CMD []
