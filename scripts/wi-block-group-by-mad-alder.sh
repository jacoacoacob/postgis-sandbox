#!/bin/bash
set -e

docker compose exec -T db psql -v ON_ERROR_STOP=1 -U postgres --no-align --tuples-only <<EOSQL
    SELECT jsonb_build_object(
        'type', 'FeatureCollection',
        'features', json_agg(t.feature)
    )
    FROM (
        SELECT jsonb_build_object(
            'type', 'Feature',
            'id', props.id,
            'geometry', ST_AsGeoJSON(ST_ReducePrecision(props.geom, 0.0001))::jsonb,
            'properties', '{}'
        ) AS feature
        FROM (
            SELECT
                TRIM(LEADING '0' FROM bg.tractce || bg.blkgrpce) id,
                bg.geom
            FROM tl_2022_55_bg AS bg
            INNER JOIN alder_districts AS ad
            ON (
                -- Only return rows where alder_district geometry area overlaps 
                -- a block group area geometry by more than 20 percent
                ST_Area(ST_Intersection(ad.geom, bg.geom)) / ST_Area(bg.geom) * 100 > 20
            )
            GROUP BY bg.gid
        ) AS props
    ) AS t
EOSQL
