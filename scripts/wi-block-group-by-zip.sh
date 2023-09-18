#!/bin/bash
set -e

if [[ $1 = --file ]]
then
    ZIPCODES="'$(echo $(tr '\n' ' ' < $2) | sed "s# #', '#g")'"
else
    ZIPCODES="'$(echo ${@:1} | sed "s# #', '#g")'"
fi

docker compose exec -T db psql -v ON_ERROR_STOP=1 -U postgres --no-align --tuples-only <<EOSQL
    SELECT jsonb_build_object(
        'type', 'FeatureCollection',
        'features', json_agg(t.feature)
    )
    FROM (
        SELECT jsonb_build_object(
            'type', 'Feature',
            'id', props.id,
            'geometry', ST_AsGeoJSON(ST_ReducePrecision(props.geom, 0.000001))::jsonb,
            'properties', to_jsonb(props.*) - 'geom' - 'id'
        ) AS feature
        FROM (
            SELECT
                bg.gid::text AS id,
                bg.geom,
                bg.namelsad AS name
            FROM tl_2022_55_bg AS bg
            INNER JOIN tl_2022_us_zcta AS zcta
            ON ST_Intersects(zcta.geom, bg.geom)
            WHERE zcta.zcta5ce20 IN (
                $ZIPCODES
            )
            GROUP BY bg.gid
        ) AS props
    ) AS t
EOSQL
