FROM  --platform=arm64 postgis/postgis AS builder

RUN apt-get update --yes --quiet && apt-get install --yes --quiet --no-install-recommends \
    less \
    postgis \
  && rm -rf /var/lib/apt/lists/* 

FROM --platform=arm64 postgis/postgis

COPY --from=builder /usr/bin/less /usr/bin/less
COPY --from=builder /usr/bin/shp2pgsql /usr/bin/shp2pgsql