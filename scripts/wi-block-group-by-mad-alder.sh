#!/bin/bash
set -e

THRESHOLD=$1

docker compose exec -T db psql -v ON_ERROR_STOP=1 -U postgres --no-align --tuples-only <<EOSQL
    SELECT jsonb_build_object(
        'type', 'FeatureCollection',
        'features', json_agg(t.feature)
    )
    FROM (
        SELECT jsonb_build_object(
            'type', 'Feature',
            'id', props.gid,
            'geometry', ST_AsGeoJSON(ST_ReducePrecision(props.geom, 0.000001))::jsonb,
            'properties', to_jsonb(props.*) - 'geom' - 'gid'
        ) AS feature
        FROM (
            SELECT
                bg.gid::text,
                bg.geom,
                bg.namelsad AS name
            FROM tl_2022_55_bg AS bg
            INNER JOIN alder_districts AS ad
            ON (
                -- Only return rows where alder_district geometry area overlaps 
                -- a block group area geometry by more than THRESHOLD percent
                ST_Area(ST_Intersection(ad.geom, bg.geom)) / ST_Area(bg.geom) * 100 > $THRESHOLD
            )
            GROUP BY bg.gid
        ) AS props
    ) AS t
EOSQL
