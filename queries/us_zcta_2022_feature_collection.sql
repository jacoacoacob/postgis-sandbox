select json_build_object(
    'type', 'FeatureCollection',
    'features', json_agg(features.feature)
    )
from (
    select jsonb_build_object(
        'type', 'Feature',
        'id', zcta.gid,
        'geometry', ST_AsGeoJSON(ST_ForceRHR(zcta.geom))::jsonb,
        'properties', jsonb_agg(geojson_props)
    ) as feature
    from (
        select 
             gid,
             zcta5ce20 as zipcode
        from us_zcta_2022
        where zcta5ce20 in (
            -- zip codes for Dane County, WI
            '53508', '53515', '53517', '53523', '53527', '53528', '53529', '53531', '53532', '53558', '53559', '53560', '53562', '53571', '53572', '53575', '53589', '53590', '53593', '53596', '53597', '53598', '53701', '53702', '53703', '53704', '53705', '53706', '53707', '53708', '53711', '53713', '53714', '53715', '53716', '53717', '53718', '53719', '53725', '53726', '53744', '53774', '53777', '53782', '53783', '53784', '53785', '53786', '53788', '53790', '53791', '53792', '53793', '53794'
        )
    ) as geojson_props
    inner join (
        select * from us_zcta_2022
    ) as zcta
    using (gid)
    group by zcta.gid, zcta.geom
) as features;
