#!/bin/bash
set -e

if [[ $1 = --file ]]
then
    STATES="'$(echo $(tr '\n' ' ' < $2) | sed "s# #', '#g")'"
else
    STATES="'$(echo ${@:1} | sed "s# #', '#g")'"
fi

docker compose exec -T db psql -v ON_ERROR_STOP=1 -U postgres --no-align --tuples-only <<EOSQL
    SELECT json_build_object(
        'type', 'FeatureCollection',
        'features', json_agg(t.feature)
    )
    FROM (
        SELECT json_build_object(
            'type', 'Feature',
            'id', gid::text,
            'geometry', ST_AsGeoJSON(geom)::json,
            'properties', json_build_object(
                'stusps', stusps,
                'name', name
            )
        ) AS feature
        FROM tl_2022_us_state
        WHERE stusps IN (
            $STATES
        )
    ) AS t
EOSQL
