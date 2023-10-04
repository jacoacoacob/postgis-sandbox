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
            'id', props.id,
            'geometry', ST_AsGeoJSON(ST_ReducePrecision(props.geom, 0.000001))::jsonb,
            'properties', to_jsonb(props) - 'geom' - 'id' - 'geoid'
        ) feature
        FROM (
            SELECT *
            FROM (
                SELECT
                    geoid                                id,
                    json_agg(to_jsonb(bgec.*) - 'geoid') evictions
                  FROM (
                    SELECT
                        COUNT(*)                           n_filings,
                        DATE_TRUNC('year', ec.filing_date) filing_year,
                        bgho.geoid                        
                      FROM bg_housing_occupancy bgho
                      JOIN eviction_cases       ec
                        ON ST_Contains(bgho.geom, ec.defendant_address_point)
                  GROUP BY filing_year, geoid
                ) bgec
              GROUP BY id
            ) bgec
            JOIN bg_housing_occupancy bgho
              ON bgec.id = bgho.geoid
        ) props
    ) f;
EOSQL
