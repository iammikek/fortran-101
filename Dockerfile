FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gfortran \
    git \
    libcrypt-dev \
    libsqlite3-dev \
    libssl-dev \
    make \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch v0.13.0 https://github.com/fortran-lang/fpm.git /tmp/fpm \
    && cd /tmp/fpm \
    && ./install.sh --prefix=/usr/local \
    && rm -rf /tmp/fpm

WORKDIR /app
COPY . .

RUN mkdir -p database \
    && fpm build --profile release \
    && install "$(find build -name fortran-101 -type f | head -n 1)" /usr/local/bin/fortran-101

EXPOSE 8008

ENV APP_PORT=8008
ENV APP_HOST=0.0.0.0
ENV DB_DATABASE=database/database.sqlite
ENV JWT_SECRET=change-me-in-production

CMD ["fortran-101"]
