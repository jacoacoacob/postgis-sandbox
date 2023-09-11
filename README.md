# PostGIS Sandbox

This repository contains tutorials and examples of little things you can do with PostGIS.

## Local setup

You'll need [Docker and Docker Compose](https://docs.docker.com/get-docker/) installed on your machine before continuing.

Inside the project root, run the following command to spin up a PostGIS database inside a docker container.
```bash
docker compose up -d
```

## Loading Shapefile data

_A lot of these steps were adapted from this [PostGIS tutorial on loading data from Shapefiles](https://postgis.net/workshops/postgis-intro/loading_data.html#shapefiles-what-s-that)._

1. Download a shapefile. You can get one from [the census](https://www.census.gov/cgi-bin/geo/shapefiles/index.php). Choose the `States (and equivelant)` option (this should be a smaller file than the others) and click submit to download.
2. Move the unzipped folder into `./shapefiles`. This will give our PostGIS docker container access to its files at `/tmp/shapefiles/`
3. Find the Spatial Reference ID (SRID) by searching `shapefiles/tl_2022_us_state/tl_2022_us_state.shp.iso.xml` for "EPSG". It'll be the 4-digit number inside xml elements that look like
    ```xml
    <gmd:code>
        <gco:CharacterString>urn:ogc:def:crs:EPSG::4269</gco:CharacterString>
    </gmd:code>
    ```
    which will be a child of a `<gmd:referenceSystemIdentifier>` element
4. Enter a shell session inside the PostGIS container.
    ```bash
    docker compose exec db bash
    ```
5. Use `shp2pgsql` and `psql` to transform and load the shapefile data into a table in the database. (In this case, I'm reprojecting from SRID `4269` to `4326`).
    ```bash
    shp2pgsql -D -I -s 4269:4326 \
        /tmp/shapefiles/tl_2022_us_state/tl_2022_us_state.shp \
        tl_2022_us_state \
        | psql -U postgres
    ```


## Generating GeoJSON

Assuming you've followed the steps for [loading shapefile data](#loading-shapefile-data) for the `Zip Code Tabulation Areas` and `States (and equivelant)` shapefiles from [the census](https://www.census.gov/cgi-bin/geo/shapefiles/index.php) into tables `tl_2022_us_zcta` and `tl_2022_us_state` respectively, you can use the shell scripts in [./scripts](./scripts/) to generate GeoJSON FeatureCollection objects. You can validate the results using the JSFiddle link from this [Mapbox example](https://docs.mapbox.com/mapbox-gl-js/example/multiple-geometries/) or with one of the other resources listed in [this PostGIS docs page](https://postgis.net/docs/en/ST_AsGeoJSON.html)

Example:
```bash
# Make sure the scripts are executable
chmod +x scripts/*

# Generate a FeatureCollection object for zipcodes 53704, 53705, and 53706 and save it in a file called zipcodes.json
scripts/us-zcta.sh 53704 53705 53706 > zipcodes.json

# Alternatively, list a bunch of zipcodes in a text file and have the script read from that
scripts/us-zcta.sh --file dane-county-zipcodes.txt > zipcodes.json
```







