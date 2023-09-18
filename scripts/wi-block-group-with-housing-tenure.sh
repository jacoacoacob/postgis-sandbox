#!/bin/bash

set -e

docker compose exec -T db psql -v ON_ERROR_STOP=1 -U postgres --no-align --tuples-only <<EOSQL
    SELECT jsonb_build_object(
        'type', 'FeatureCollection',
        'features', jsonb_agg(f.feature)
    )
    FROM (
        SELECT jsonb_build_object(
            'type', 'Feature',
            'id', props.geoid,
            'geometry', ST_AsGeoJSON(ST_ReducePrecision(props.geom, 0.000001))::jsonb,
            'properties', to_jsonb(props) - 'geom'
        ) feature
        FROM (
            SELECT
                hc.*,
                bg.geoid,
                bg.geom
            FROM tl_2022_55_bg    bg
            JOIN tl_2022_55_tract tr
                ON bg.countyfp = tr.countyfp AND bg.tractce = tr.tractce
            JOIN housing_census   hc
                ON tr.name = hc.tract AND bg.blkgrpce = hc.block_group::text
            WHERE bg.countyfp = '025'
        ) props
    ) f;
EOSQL


