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
            SELECT
                madbg.block_group_name || '_' ||EXTRACT(YEAR FROM madbg.filing_year) id,
                madbg.block_group_name geog_name,
                madbg.filing_year,
                ec.n_filings,
                case
                  when ec.n_filings = 0 then 0
                  when ho.renter_count = 0 then 0
                  else round(((ec.n_filings::float / ho.renter_count::float) * 100)::numeric, 2)
                end AS filing_rate,
                ho.owner_count,
                ho.renter_count,
                madbg.geom
              FROM mad_block_groups madbg
              JOIN tl_2022_55_bg    tlbg
                ON madbg.gid = tlbg.gid::text
              JOIN tl_2022_55_tract tr
                ON tlbg.countyfp = tr.countyfp AND tlbg.tractce = tr.tractce
              JOIN housing_census   ho
                ON ho.tract = tr.name AND tlbg.blkgrpce = ho.block_group::text
              JOIN (
                        SELECT
                            gid,
                            filing_year,
                            COUNT(defendant_address) n_filings
                          FROM mad_block_groups madbg
               LEFT OUTER JOIN eviction_cases   ec
                            ON
                              ST_Contains(madbg.geom, ec.defendant_address_point) AND
                              madbg.filing_year = DATE_TRUNC('year', ec.filing_date)
                      GROUP BY gid, filing_year
              ) ec
                ON ec.gid = madbg.gid AND ec.filing_year = madbg.filing_year
        ) props
    ) f;
EOSQL
