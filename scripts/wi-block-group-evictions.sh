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
            'geometry', ST_AsGeoJSON(ST_Centroid(props.geom))::jsonb,
            'properties', to_jsonb(props) - 'geom'
        ) feature
        FROM (
            SELECT
                dane_bg.filing_year || dane_bg.block_group_name id,
                'Block Group ' || dane_bg.block_group_name geog_name,
                dane_bg.filing_year::text,
                ec.n_filings,
                case
                  when ec.n_filings = 0 then 0
                  when ho.renter_count = 0 then 0
                  else round(((ec.n_filings::float / ho.renter_count::float) * 100)::numeric)
                end AS filing_rate,
                ho.owner_count,
                ho.renter_count,
                dane_bg.geom
              FROM dane_block_groups dane_bg
              JOIN tl_2022_55_bg    tlbg
                ON dane_bg.gid = tlbg.gid::text
              JOIN tl_2022_55_tract tr
                ON tlbg.countyfp = tr.countyfp AND tlbg.tractce = tr.tractce
              JOIN housing_census   ho
                ON ho.tract = tr.name AND tlbg.blkgrpce = ho.block_group::text
              JOIN (
                        SELECT
                            gid,
                            filing_year,
                            COUNT(defendant_address) n_filings
                          FROM dane_block_groups dane_bg
               LEFT OUTER JOIN eviction_cases   ec
                            ON
                              ST_Contains(dane_bg.geom, ec.defendant_address_point) AND
                              dane_bg.filing_year = EXTRACT(YEAR FROM ec.filing_date)
                      GROUP BY gid, filing_year
              ) ec
                ON ec.gid = dane_bg.gid AND ec.filing_year = dane_bg.filing_year
        ) props
    ) f;
EOSQL
