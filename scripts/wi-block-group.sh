#!/bin/bash

set -e

docker compose exec -T db psql -v ON_ERROR_STOP=1 -U postgres --no-align --tuples-only <<EOSQL
    SELECT jsonb_build_object(
      'type', 'FeatureCollection',
      'features', jsonb_agg(f.demographic_metrics_feature) || jsonb_agg(f.eviction_metrics_feature)
    )
    FROM (
        SELECT

          jsonb_build_object(
            'type', 'Feature',
            'id', props.id || '_' || 'demo',
            'geometry', ST_AsGeoJSON(
              ST_ReducePrecision(
                ST_SimplifyPreserveTopology(props.geom, 0.0001), 0.000001
              )
            )::jsonb,
            'properties', jsonb_build_object(
              'area_kind', props.area_kind,
              'id', props.id,
              'owner_count', props.owner_count,
              'renter_count', props.renter_count
            )
          ) demographic_metrics_feature,

          jsonb_build_object(
            'type', 'Feature',
            'id', props.id || '_' || 'evct',
            'geometry', ST_AsGeoJSON(ST_Centroid(props.geom))::jsonb,
            'properties', jsonb_build_object(
              'id', props.id,
              'area_kind', props.area_kind,
              'evictions', props.evictions
            )
          ) eviction_metrics_feature

        FROM (
            SELECT
                ec.evictions,
                bgho.*
            FROM (
                SELECT
                    id,
                    'Block Group' area_kind,
                    jsonb_object_agg(
                      t.filing_year,
                      jsonb_build_object(
                        'n_filings', t.n_filings,
                        'filing_rate', t.filing_rate
                      )
                    ) evictions
                fROM (
                    SELECT
                        ec.*,
                        case
                            when ec.n_filings = 0 then 0
                            when bgho.renter_count = 0 then 0
                            else round(((ec.n_filings::float / bgho.renter_count::float) * 100)::numeric)
                        end filing_rate,
                        bgho.*
                    FROM (
                        SELECT
                            block_group_name,
                            filing_year::text,
                            COUNT(defendant_address) n_filings
                          FROM dane_block_groups          bg
                          LEFT OUTER JOIN eviction_cases  ec
                            ON
                              ST_Contains(bg.geom, ec.defendant_address_point) AND
                              bg.filing_year = EXTRACT(YEAR FROM ec.filing_date)
                        GROUP BY block_group_name, filing_year
                      ) ec
                      JOIN (
                        SELECT
                            TRIM(LEADING '0' FROM bg.tractce) || blkgrpce id,
                            ho.owner_count,
                            ho.renter_count
                          FROM tl_2022_55_bg    bg
                          JOIN tl_2022_55_tract tr
                            ON bg.countyfp = tr.countyfp AND bg.tractce = tr.tractce
                          JOIN housing_census   ho
                            ON ho.tract = tr.name AND bg.blkgrpce = ho.block_group::text
                         WHERE bg.countyfp = '025'
                      ) bgho
                      ON ec.block_group_name = bgho.id
                    ) t
                    GROUP BY id
            ) ec
            JOIN (
                SELECT
                    'Block Group'                                   area_kind,
                    TRIM(LEADING '0' FROM bg.tractce) || blkgrpce   id,
                    ho.owner_count,
                    ho.renter_count,
                    bg.geom
                FROM tl_2022_55_bg    bg
                JOIN tl_2022_55_tract tr
                  ON bg.countyfp = tr.countyfp AND bg.tractce = tr.tractce
                JOIN housing_census   ho
                  ON ho.tract = tr.name AND bg.blkgrpce = ho.block_group::text
                WHERE bg.countyfp = '025'
            ) bgho
            ON bgho.id = ec.id
        ) props
    ) f
EOSQL
