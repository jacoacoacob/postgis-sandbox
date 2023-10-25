#!/bin/bash

set -e

docker compose exec -T db psql -v ON_ERROR_STOP=1 -U postgres --no-align --tuples-only <<EOSQL
    SELECT jsonb_build_object(
        'type', 'FeatureCollection',
        'features', jsonb_agg(t.feature)
    )
    FROM (
        SELECT jsonb_build_object(
            'type', 'Feature',
            'id', props.id,
            'geometry', ST_AsGeoJSON(
                ST_SimplifyPreserveTopology(
                    props.geom,
                    0.0001
                )
            )::jsonb,
            'properties', '{}'
        ) AS feature
        FROM (
            SELECT
                TRIM(LEADING '0' FROM bg.tractce || bg.blkgrpce) id,
                bg.geom
            FROM tl_2022_55_bg bg
            WHERE bg.countyfp = '025'
        ) props
    ) t
EOSQL
