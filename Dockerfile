FROM python:3.12-alpine
WORKDIR /app
COPY serve.py index.html ./
RUN adduser -D -u 10001 -h /app noc && mkdir -p /app/data && chown noc /app/data
USER noc
ENV PORT=8080
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8080/api/health').status==200 else 1)"
CMD ["python", "serve.py"]
