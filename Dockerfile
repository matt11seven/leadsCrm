FROM docker/compose:alpine-1.29.2

WORKDIR /app

COPY . .

CMD ["docker-compose", "up", "-d"]
