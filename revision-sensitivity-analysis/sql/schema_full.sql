--
-- PostgreSQL database dump
--

\restrict 8nb1qLNMUkffRgPeQ1PTCSMINnPKbCW90Be5DtCLHixFKOEXIWm1I8rf6eqDD3c

-- Dumped from database version 16.15 (Ubuntu 16.15-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.15 (Ubuntu 16.15-0ubuntu0.24.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: hstore; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS hstore WITH SCHEMA public;


--
-- Name: EXTENSION hstore; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION hstore IS 'data type for storing sets of (key, value) pairs';


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- Name: pgrouting; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgrouting WITH SCHEMA public;


--
-- Name: EXTENSION pgrouting; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgrouting IS 'pgRouting Extension';


--
-- Name: build_road_grid_cell_map(); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.build_road_grid_cell_map()
    LANGUAGE plpgsql
    AS $$
BEGIN
    TRUNCATE TABLE road_segment_grid_map;

    INSERT INTO road_segment_grid_map (
        road_segment_id,
        grid_cell_id,
        intersect_length_m,
        length_ratio
    )
    SELECT
        rs.id AS road_segment_id,
        gc.id AS grid_cell_id,
        ST_Length(
            ST_Intersection(
                ST_Transform(rs.geometry, 32616),
                ST_Transform(gc.geom, 32616)
            )
        ) AS intersect_length_m,
        ST_Length(
            ST_Intersection(
                ST_Transform(rs.geometry, 32616),
                ST_Transform(gc.geom, 32616)
            )
        ) / NULLIF(
            ST_Length(ST_Transform(rs.geometry, 32616)),
            0
        ) AS length_ratio,
        NOW()
    FROM road_segments rs
    JOIN grid_cells gc
      ON ST_Intersects(rs.geometry, gc.geom)
    WHERE ST_Length(
        ST_Intersection(
            ST_Transform(rs.geometry, 32616),
            ST_Transform(gc.geom, 32616)
        )
    ) > 0;
END;
$$;


--
-- Name: build_road_segment_cell_map(); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.build_road_segment_cell_map()
    LANGUAGE plpgsql
    AS $$
BEGIN
    TRUNCATE TABLE road_segment_cell_map;

    INSERT INTO road_segment_cell_map (
        road_segment_id,
        cell_id,
        intersect_length_m,
        length_ratio,
        created_at
    )
    SELECT
        rs.id AS road_segment_id,
        gc.id AS cell_id,
        ST_Length(
            ST_Intersection(
                ST_Transform(rs.geometry, 32616),
                ST_Transform(gc.geom, 32616)
            )
        ) AS intersect_length_m,
        ST_Length(
            ST_Intersection(
                ST_Transform(rs.geometry, 32616),
                ST_Transform(gc.geom, 32616)
            )
        ) / NULLIF(
            ST_Length(ST_Transform(rs.geometry, 32616)),
            0
        ) AS length_ratio,
        NOW()
    FROM road_segments rs
    JOIN grid_cells gc
      ON ST_Intersects(rs.geometry, gc.geom)
    WHERE ST_Length(
        ST_Intersection(
            ST_Transform(rs.geometry, 32616),
            ST_Transform(gc.geom, 32616)
        )
    ) > 0;
END;
$$;


--
-- Name: build_road_segment_grid_map(); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.build_road_segment_grid_map()
    LANGUAGE plpgsql
    AS $$
BEGIN
    TRUNCATE TABLE road_segment_grid_map;

    INSERT INTO road_segment_grid_map (
        road_segment_id,
        cell_id,
        intersect_length_m,
        length_ratio,
        created_at
    )
    SELECT
        rs.id AS road_segment_id,
        gc.id AS cell_id,
        ST_Length(
            ST_Intersection(
                ST_Transform(rs.geometry, 32616),
                ST_Transform(gc.geom, 32616)
            )
        ) AS intersect_length_m,
        ST_Length(
            ST_Intersection(
                ST_Transform(rs.geometry, 32616),
                ST_Transform(gc.geom, 32616)
            )
        ) / NULLIF(
            ST_Length(ST_Transform(rs.geometry, 32616)),
            0
        ) AS length_ratio,
        NOW()
    FROM road_segments rs
    JOIN grid_cells gc
      ON ST_Intersects(rs.geometry, gc.geom)
    WHERE ST_Length(
        ST_Intersection(
            ST_Transform(rs.geometry, 32616),
            ST_Transform(gc.geom, 32616)
        )
    ) > 0;
END;
$$;


--
-- Name: calculate_cell_risk_scores_chi_temporal(date, date, double precision, text, text); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.calculate_cell_risk_scores_chi_temporal(IN p_start_date date DEFAULT '2021-01-01'::date, IN p_end_date date DEFAULT '2026-12-31'::date, IN p_lambda double precision DEFAULT 0.7, IN p_score_type text DEFAULT 'chi_temporal_exp'::text, IN p_calculation_version text DEFAULT 'v1'::text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM cell_risk_scores
    WHERE score_type = p_score_type
      AND start_date = p_start_date
      AND end_date = p_end_date
      AND calculation_version = p_calculation_version;

    INSERT INTO cell_risk_scores (
        cell_id,
        score,
        score_type,
        start_date,
        end_date,
        calculation_version,
        created_at
    )
    SELECT
        c.cell_id,
        SUM(
            c.harm_weight *
            EXP(
                -p_lambda *
                (
                    EXTRACT(EPOCH FROM (p_end_date::timestamp - c."Date")) 
                    / (365.25 * 24 * 60 * 60)
                )
            )
        ) AS score,
        p_score_type,
        p_start_date,
        p_end_date,
        p_calculation_version,
        NOW()
    FROM crime c
    WHERE c.cell_id IS NOT NULL
      AND c.harm_weight IS NOT NULL
      AND c."Date" >= p_start_date
      AND c."Date" < (p_end_date + INTERVAL '1 day')
    GROUP BY c.cell_id;
END;
$$;


--
-- Name: calculate_cell_risk_scores_v2(date, date, double precision, text, text); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.calculate_cell_risk_scores_v2(IN p_start_date date DEFAULT '2021-01-01'::date, IN p_end_date date DEFAULT '2026-12-31'::date, IN p_lambda double precision DEFAULT 0.7, IN p_score_type text DEFAULT 'chi_temporal_log_p95'::text, IN p_calculation_version text DEFAULT 'v2'::text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM cell_risk_scores
    WHERE score_type = p_score_type
      AND start_date = p_start_date
      AND end_date = p_end_date
      AND calculation_version = p_calculation_version;

    WITH cell_raw AS (
        SELECT
            c.cell_id,
            SUM(
                c.harm_weight *
                EXP(
                    -p_lambda *
                    (
                        EXTRACT(EPOCH FROM (p_end_date::timestamp - c."Date"))
                        / (365.25 * 24 * 60 * 60)
                    )
                )
            ) AS raw_score
        FROM crime c
        WHERE c.cell_id IS NOT NULL
          AND c.harm_weight IS NOT NULL
          AND c."Date" >= p_start_date
          AND c."Date" < (p_end_date + INTERVAL '1 day')
        GROUP BY c.cell_id
    ),
    p95_value AS (
        SELECT
            PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY raw_score) AS p95_raw
        FROM cell_raw
    )
    INSERT INTO cell_risk_scores (
        cell_id,
        score,
        raw_score,
        risk_level,
        score_type,
        start_date,
        end_date,
        calculation_version,
        created_at
    )
    SELECT
        cr.cell_id,

        ROUND(
            LEAST(
                100.0,
                100.0 * LN(1 + cr.raw_score) / NULLIF(LN(1 + p.p95_raw), 0)
            )::numeric,
            2
        ) AS score,

        ROUND(cr.raw_score::numeric, 6) AS raw_score,

        CASE
            WHEN LEAST(
                100.0,
                100.0 * LN(1 + cr.raw_score) / NULLIF(LN(1 + p.p95_raw), 0)
            ) < 35 THEN 'LOW'
            WHEN LEAST(
                100.0,
                100.0 * LN(1 + cr.raw_score) / NULLIF(LN(1 + p.p95_raw), 0)
            ) < 70 THEN 'MEDIUM'
            ELSE 'HIGH'
        END AS risk_level,

        p_score_type,
        p_start_date,
        p_end_date,
        p_calculation_version,
        NOW()
    FROM cell_raw cr
    CROSS JOIN p95_value p;
END;
$$;


--
-- Name: planet_osm_index_bucket(bigint[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.planet_osm_index_bucket(bigint[]) RETURNS bigint[]
    LANGUAGE sql IMMUTABLE
    AS $_$  SELECT ARRAY(SELECT DISTINCT    unnest($1) >> 5)$_$;


--
-- Name: planet_osm_line_osm2pgsql_valid(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.planet_osm_line_osm2pgsql_valid() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF ST_IsValid(NEW.way) THEN 
    RETURN NEW;
  END IF;
  RETURN NULL;
END;$$;


--
-- Name: planet_osm_member_ids(jsonb, character); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.planet_osm_member_ids(jsonb, character) RETURNS bigint[]
    LANGUAGE sql IMMUTABLE
    AS $_$  SELECT array_agg((el->>'ref')::int8)   FROM jsonb_array_elements($1) AS el    WHERE el->>'type' = $2$_$;


--
-- Name: planet_osm_point_osm2pgsql_valid(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.planet_osm_point_osm2pgsql_valid() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF ST_IsValid(NEW.way) THEN 
    RETURN NEW;
  END IF;
  RETURN NULL;
END;$$;


--
-- Name: planet_osm_polygon_osm2pgsql_valid(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.planet_osm_polygon_osm2pgsql_valid() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF ST_IsValid(NEW.way) THEN 
    RETURN NEW;
  END IF;
  RETURN NULL;
END;$$;


--
-- Name: planet_osm_roads_osm2pgsql_valid(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.planet_osm_roads_osm2pgsql_valid() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF ST_IsValid(NEW.way) THEN 
    RETURN NEW;
  END IF;
  RETURN NULL;
END;$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: cell_risk_scores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cell_risk_scores (
    id bigint NOT NULL,
    cell_id bigint NOT NULL,
    score double precision NOT NULL,
    score_type text,
    start_date date,
    end_date date,
    calculation_version text,
    created_at timestamp without time zone DEFAULT now(),
    raw_score numeric,
    risk_level text,
    normalized_score double precision
);


--
-- Name: cell_risk_scores_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.cell_risk_scores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: cell_risk_scores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.cell_risk_scores_id_seq OWNED BY public.cell_risk_scores.id;


--
-- Name: configuration; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.configuration (
    id integer NOT NULL,
    tag_id integer,
    tag_key text,
    tag_value text,
    priority double precision,
    maxspeed double precision,
    maxspeed_forward double precision,
    maxspeed_backward double precision,
    force character(1)
)
WITH (autovacuum_enabled='false');


--
-- Name: configuration_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.configuration_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: configuration_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.configuration_id_seq OWNED BY public.configuration.id;


--
-- Name: crime; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crime (
    "Date" timestamp without time zone,
    "Primary Type" text,
    "Description" text,
    "Latitude" double precision,
    "Longitude" double precision,
    "Location" text,
    geom public.geometry(Point,4326),
    cell_id bigint,
    harm_weight double precision,
    crime_group text,
    id bigint NOT NULL
);


--
-- Name: crime_grid_daily; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crime_grid_daily (
    date_only date,
    grid_id bigint,
    total_count bigint,
    mala_karsi_count bigint,
    siddet_count bigint,
    uyusturucu_ahlaki_count bigint,
    kamu_duzeni_count bigint,
    diger_count bigint,
    avg_harm_weight double precision,
    total_harm_score double precision,
    year integer,
    month integer,
    day integer,
    dayofweek integer,
    is_weekend integer,
    mala_karsi_ratio double precision,
    siddet_ratio double precision,
    uyusturucu_ahlaki_ratio double precision,
    kamu_duzeni_ratio double precision,
    diger_ratio double precision,
    grid_lat double precision,
    grid_lon double precision,
    dist_to_center_km double precision,
    lag_1d double precision,
    lag_7d double precision,
    lag_14d double precision,
    lag_30d double precision,
    rolling_7d_mean double precision,
    rolling_30d_mean double precision,
    dominant_crime_group text,
    has_mala_karsi integer,
    has_siddet integer,
    has_kamu_duzeni integer,
    has_uyusturucu integer,
    neighbor_total_count double precision,
    neighbor_7d_mean double precision,
    neighbor_30d_mean double precision,
    neighbor_prev_7d_mean double precision,
    month_sin double precision,
    month_cos double precision,
    dow_sin double precision,
    dow_cos double precision,
    crime_density double precision,
    neighbor_prev_1d double precision
);


--
-- Name: crime_grid_weekly; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crime_grid_weekly (
    week_start date,
    grid_id bigint,
    total_count bigint,
    mala_karsi_count bigint,
    siddet_count bigint,
    kamu_duzeni_count bigint,
    uyusturucu_count bigint,
    total_harm_score double precision,
    avg_harm_weight double precision,
    year integer,
    month integer,
    weekofyear integer,
    month_sin double precision,
    month_cos double precision,
    week_sin double precision,
    week_cos double precision,
    grid_lat double precision,
    grid_lon double precision,
    dist_to_center_km double precision,
    lag_1w double precision,
    lag_2w double precision,
    lag_4w double precision,
    lag_8w double precision,
    rolling_4w_mean double precision,
    rolling_8w_mean double precision,
    rolling_12w_mean double precision,
    neighbor_prev_1w double precision,
    neighbor_prev_4w_mean double precision,
    has_mala_karsi integer,
    has_siddet integer,
    has_kamu_duzeni integer,
    has_uyusturucu integer,
    dominant_crime_group text,
    lag_3w double precision,
    lag_12w double precision,
    lag_26w double precision,
    lag_52w double precision,
    rolling_4w_std double precision,
    rolling_8w_std double precision,
    rolling_12w_std double precision,
    rolling_4w_max double precision,
    rolling_12w_max double precision,
    momentum_4_12 double precision,
    zero_ratio_12w double precision,
    weeks_since_last_crime double precision,
    neighbor_momentum double precision,
    historical_density_rank double precision,
    last_crime_date date
);


--
-- Name: crime_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.crime_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: crime_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.crime_id_seq OWNED BY public.crime.id;


--
-- Name: crime_type_mapping; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crime_type_mapping (
    primary_type text NOT NULL,
    crime_group text NOT NULL,
    harm_weight double precision NOT NULL
);


--
-- Name: grid_cells; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.grid_cells (
    id bigint NOT NULL,
    cell_code text,
    geom public.geometry(Polygon,4326),
    centroid_geom public.geometry(Point,4326),
    area_m2 double precision
);


--
-- Name: grid_cells_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.grid_cells_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: grid_cells_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.grid_cells_id_seq OWNED BY public.grid_cells.id;


--
-- Name: grid_neighbors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.grid_neighbors (
    grid_id bigint,
    neighbor_grid_id bigint
);


--
-- Name: osm2pgsql_properties; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.osm2pgsql_properties (
    property text NOT NULL,
    value text NOT NULL
);


--
-- Name: planet_osm_line; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.planet_osm_line (
    osm_id bigint,
    access text,
    "addr:housename" text,
    "addr:housenumber" text,
    "addr:interpolation" text,
    admin_level text,
    aerialway text,
    aeroway text,
    amenity text,
    area text,
    barrier text,
    bicycle text,
    brand text,
    bridge text,
    boundary text,
    building text,
    construction text,
    covered text,
    culvert text,
    cutting text,
    denomination text,
    disused text,
    embankment text,
    foot text,
    "generator:source" text,
    harbour text,
    highway text,
    historic text,
    horse text,
    intermittent text,
    junction text,
    landuse text,
    layer text,
    leisure text,
    lock text,
    man_made text,
    military text,
    motorcar text,
    name text,
    "natural" text,
    office text,
    oneway text,
    operator text,
    place text,
    population text,
    power text,
    power_source text,
    public_transport text,
    railway text,
    ref text,
    religion text,
    route text,
    service text,
    shop text,
    sport text,
    surface text,
    toll text,
    tourism text,
    "tower:type" text,
    tracktype text,
    tunnel text,
    water text,
    waterway text,
    wetland text,
    width text,
    wood text,
    z_order integer,
    way_area real,
    tags public.hstore,
    way public.geometry(LineString,3857)
);


--
-- Name: planet_osm_nodes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.planet_osm_nodes (
    id bigint NOT NULL,
    lat integer NOT NULL,
    lon integer NOT NULL,
    tags jsonb
);


--
-- Name: planet_osm_point; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.planet_osm_point (
    osm_id bigint,
    access text,
    "addr:housename" text,
    "addr:housenumber" text,
    "addr:interpolation" text,
    admin_level text,
    aerialway text,
    aeroway text,
    amenity text,
    area text,
    barrier text,
    bicycle text,
    brand text,
    bridge text,
    boundary text,
    building text,
    capital text,
    construction text,
    covered text,
    culvert text,
    cutting text,
    denomination text,
    disused text,
    ele text,
    embankment text,
    foot text,
    "generator:source" text,
    harbour text,
    highway text,
    historic text,
    horse text,
    intermittent text,
    junction text,
    landuse text,
    layer text,
    leisure text,
    lock text,
    man_made text,
    military text,
    motorcar text,
    name text,
    "natural" text,
    office text,
    oneway text,
    operator text,
    place text,
    population text,
    power text,
    power_source text,
    public_transport text,
    railway text,
    ref text,
    religion text,
    route text,
    service text,
    shop text,
    sport text,
    surface text,
    toll text,
    tourism text,
    "tower:type" text,
    tunnel text,
    water text,
    waterway text,
    wetland text,
    width text,
    wood text,
    z_order integer,
    tags public.hstore,
    way public.geometry(Point,3857)
);


--
-- Name: planet_osm_polygon; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.planet_osm_polygon (
    osm_id bigint,
    access text,
    "addr:housename" text,
    "addr:housenumber" text,
    "addr:interpolation" text,
    admin_level text,
    aerialway text,
    aeroway text,
    amenity text,
    area text,
    barrier text,
    bicycle text,
    brand text,
    bridge text,
    boundary text,
    building text,
    construction text,
    covered text,
    culvert text,
    cutting text,
    denomination text,
    disused text,
    embankment text,
    foot text,
    "generator:source" text,
    harbour text,
    highway text,
    historic text,
    horse text,
    intermittent text,
    junction text,
    landuse text,
    layer text,
    leisure text,
    lock text,
    man_made text,
    military text,
    motorcar text,
    name text,
    "natural" text,
    office text,
    oneway text,
    operator text,
    place text,
    population text,
    power text,
    power_source text,
    public_transport text,
    railway text,
    ref text,
    religion text,
    route text,
    service text,
    shop text,
    sport text,
    surface text,
    toll text,
    tourism text,
    "tower:type" text,
    tracktype text,
    tunnel text,
    water text,
    waterway text,
    wetland text,
    width text,
    wood text,
    z_order integer,
    way_area real,
    tags public.hstore,
    way public.geometry(Geometry,3857)
);


--
-- Name: planet_osm_rels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.planet_osm_rels (
    id bigint NOT NULL,
    members jsonb NOT NULL,
    tags jsonb
);


--
-- Name: planet_osm_roads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.planet_osm_roads (
    osm_id bigint,
    access text,
    "addr:housename" text,
    "addr:housenumber" text,
    "addr:interpolation" text,
    admin_level text,
    aerialway text,
    aeroway text,
    amenity text,
    area text,
    barrier text,
    bicycle text,
    brand text,
    bridge text,
    boundary text,
    building text,
    construction text,
    covered text,
    culvert text,
    cutting text,
    denomination text,
    disused text,
    embankment text,
    foot text,
    "generator:source" text,
    harbour text,
    highway text,
    historic text,
    horse text,
    intermittent text,
    junction text,
    landuse text,
    layer text,
    leisure text,
    lock text,
    man_made text,
    military text,
    motorcar text,
    name text,
    "natural" text,
    office text,
    oneway text,
    operator text,
    place text,
    population text,
    power text,
    power_source text,
    public_transport text,
    railway text,
    ref text,
    religion text,
    route text,
    service text,
    shop text,
    sport text,
    surface text,
    toll text,
    tourism text,
    "tower:type" text,
    tracktype text,
    tunnel text,
    water text,
    waterway text,
    wetland text,
    width text,
    wood text,
    z_order integer,
    way_area real,
    tags public.hstore,
    way public.geometry(LineString,3857)
);


--
-- Name: planet_osm_ways; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.planet_osm_ways (
    id bigint NOT NULL,
    nodes bigint[] NOT NULL,
    tags jsonb
);


--
-- Name: pointsofinterest; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pointsofinterest (
    pid bigint NOT NULL,
    osm_id bigint,
    vertex_id bigint,
    edge_id bigint,
    side character(1),
    fraction double precision,
    length_m double precision,
    tag_name text,
    tag_value text,
    name text,
    the_geom public.geometry(Point,4326),
    new_geom public.geometry(Point,4326)
)
WITH (autovacuum_enabled='false');


--
-- Name: pointsofinterest_pid_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.pointsofinterest_pid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: pointsofinterest_pid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.pointsofinterest_pid_seq OWNED BY public.pointsofinterest.pid;


--
-- Name: road_nodes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.road_nodes (
    osmid bigint,
    y double precision,
    x double precision,
    street_count bigint,
    highway text,
    ref text,
    junction text,
    railway text,
    geometry public.geometry(Point,4326),
    id bigint NOT NULL
);


--
-- Name: road_nodes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.road_nodes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: road_nodes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.road_nodes_id_seq OWNED BY public.road_nodes.id;


--
-- Name: road_segment_grid_map; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.road_segment_grid_map (
    id bigint NOT NULL,
    road_segment_id bigint NOT NULL,
    grid_cell_id bigint NOT NULL,
    intersect_length_m double precision NOT NULL,
    weight_contribution double precision
);


--
-- Name: road_segment_grid_map_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.road_segment_grid_map_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: road_segment_grid_map_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.road_segment_grid_map_id_seq OWNED BY public.road_segment_grid_map.id;


--
-- Name: road_segment_risk_view; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.road_segment_risk_view AS
 SELECT road_segment_id,
    COALESCE(sum(weight_contribution), (0)::double precision) AS risk_score
   FROM public.road_segment_grid_map
  GROUP BY road_segment_id;


--
-- Name: road_segments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.road_segments (
    u bigint,
    v bigint,
    key bigint,
    osmid text,
    highway text,
    lanes text,
    maxspeed text,
    name text,
    oneway boolean,
    ref text,
    reversed text,
    length double precision,
    geometry public.geometry(LineString,4326),
    access text,
    bridge text,
    tunnel text,
    width text,
    service text,
    junction text,
    area text,
    source_node bigint,
    target_node bigint,
    length_m double precision,
    base_cost double precision,
    safety_cost double precision,
    total_cost double precision,
    id bigint NOT NULL,
    source_geom public.geometry(Point,4326),
    target_geom public.geometry(Point,4326),
    allowed_car boolean DEFAULT false,
    allowed_walk boolean DEFAULT false
);


--
-- Name: road_segments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.road_segments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: road_segments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.road_segments_id_seq OWNED BY public.road_segments.id;


--
-- Name: ways; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ways (
    gid bigint NOT NULL,
    osm_id bigint,
    tag_id integer,
    length double precision,
    length_m double precision,
    name text,
    source bigint,
    target bigint,
    source_osm bigint,
    target_osm bigint,
    cost double precision,
    reverse_cost double precision,
    cost_s double precision,
    reverse_cost_s double precision,
    rule text,
    one_way integer,
    oneway text,
    x1 double precision,
    y1 double precision,
    x2 double precision,
    y2 double precision,
    maxspeed_forward double precision,
    maxspeed_backward double precision,
    priority double precision DEFAULT 1,
    the_geom public.geometry(LineString,4326)
)
WITH (autovacuum_enabled='false');


--
-- Name: ways_gid_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ways_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ways_gid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ways_gid_seq OWNED BY public.ways.gid;


--
-- Name: ways_vertices_pgr; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ways_vertices_pgr (
    id bigint NOT NULL,
    osm_id bigint,
    eout integer,
    lon numeric(11,8),
    lat numeric(11,8),
    cnt integer,
    chk integer,
    ein integer,
    the_geom public.geometry(Point,4326)
)
WITH (autovacuum_enabled='false');


--
-- Name: ways_vertices_pgr_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.ways_vertices_pgr_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: ways_vertices_pgr_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.ways_vertices_pgr_id_seq OWNED BY public.ways_vertices_pgr.id;


--
-- Name: weekly_predicted_crime; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.weekly_predicted_crime (
    id bigint NOT NULL,
    prediction_week_start date NOT NULL,
    grid_id bigint NOT NULL,
    predicted_total_count double precision,
    predicted_risk_level integer,
    predicted_risk_name text,
    predicted_main_crime_group text,
    prob_low double precision,
    prob_medium double precision,
    prob_high double precision,
    prob_mala_karsi double precision,
    prob_siddet double precision,
    prob_kamu_duzeni double precision,
    prob_uyusturucu double precision,
    predicted_mala_karsi integer,
    predicted_siddet integer,
    predicted_kamu_duzeni integer,
    predicted_uyusturucu integer,
    prediction_confidence double precision,
    harm_weight double precision,
    latitude double precision,
    longitude double precision,
    geom public.geometry(Point,4326),
    model_name text DEFAULT 'xgboost_weekly'::text,
    created_at timestamp without time zone DEFAULT now(),
    dominant_crime_class integer,
    dominant_crime_confidence double precision
);


--
-- Name: weekly_predicted_crime_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.weekly_predicted_crime_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: weekly_predicted_crime_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.weekly_predicted_crime_id_seq OWNED BY public.weekly_predicted_crime.id;


--
-- Name: cell_risk_scores id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cell_risk_scores ALTER COLUMN id SET DEFAULT nextval('public.cell_risk_scores_id_seq'::regclass);


--
-- Name: configuration id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.configuration ALTER COLUMN id SET DEFAULT nextval('public.configuration_id_seq'::regclass);


--
-- Name: crime id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crime ALTER COLUMN id SET DEFAULT nextval('public.crime_id_seq'::regclass);


--
-- Name: grid_cells id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grid_cells ALTER COLUMN id SET DEFAULT nextval('public.grid_cells_id_seq'::regclass);


--
-- Name: pointsofinterest pid; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pointsofinterest ALTER COLUMN pid SET DEFAULT nextval('public.pointsofinterest_pid_seq'::regclass);


--
-- Name: road_nodes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.road_nodes ALTER COLUMN id SET DEFAULT nextval('public.road_nodes_id_seq'::regclass);


--
-- Name: road_segment_grid_map id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.road_segment_grid_map ALTER COLUMN id SET DEFAULT nextval('public.road_segment_grid_map_id_seq'::regclass);


--
-- Name: road_segments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.road_segments ALTER COLUMN id SET DEFAULT nextval('public.road_segments_id_seq'::regclass);


--
-- Name: ways gid; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ways ALTER COLUMN gid SET DEFAULT nextval('public.ways_gid_seq'::regclass);


--
-- Name: ways_vertices_pgr id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ways_vertices_pgr ALTER COLUMN id SET DEFAULT nextval('public.ways_vertices_pgr_id_seq'::regclass);


--
-- Name: weekly_predicted_crime id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.weekly_predicted_crime ALTER COLUMN id SET DEFAULT nextval('public.weekly_predicted_crime_id_seq'::regclass);


--
-- Name: cell_risk_scores cell_risk_scores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cell_risk_scores
    ADD CONSTRAINT cell_risk_scores_pkey PRIMARY KEY (id);


--
-- Name: crime crime_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crime
    ADD CONSTRAINT crime_pkey PRIMARY KEY (id);


--
-- Name: crime_type_mapping crime_type_mapping_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crime_type_mapping
    ADD CONSTRAINT crime_type_mapping_pkey PRIMARY KEY (primary_type);


--
-- Name: grid_cells grid_cells_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grid_cells
    ADD CONSTRAINT grid_cells_pkey PRIMARY KEY (id);


--
-- Name: osm2pgsql_properties osm2pgsql_properties_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.osm2pgsql_properties
    ADD CONSTRAINT osm2pgsql_properties_pkey PRIMARY KEY (property);


--
-- Name: planet_osm_nodes planet_osm_nodes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.planet_osm_nodes
    ADD CONSTRAINT planet_osm_nodes_pkey PRIMARY KEY (id);


--
-- Name: planet_osm_rels planet_osm_rels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.planet_osm_rels
    ADD CONSTRAINT planet_osm_rels_pkey PRIMARY KEY (id);


--
-- Name: planet_osm_ways planet_osm_ways_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.planet_osm_ways
    ADD CONSTRAINT planet_osm_ways_pkey PRIMARY KEY (id);


--
-- Name: road_nodes road_nodes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.road_nodes
    ADD CONSTRAINT road_nodes_pkey PRIMARY KEY (id);


--
-- Name: road_segment_grid_map road_segment_grid_map_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.road_segment_grid_map
    ADD CONSTRAINT road_segment_grid_map_pkey PRIMARY KEY (id);


--
-- Name: road_segment_grid_map road_segment_grid_map_road_segment_id_grid_cell_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.road_segment_grid_map
    ADD CONSTRAINT road_segment_grid_map_road_segment_id_grid_cell_id_key UNIQUE (road_segment_id, grid_cell_id);


--
-- Name: road_segments road_segments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.road_segments
    ADD CONSTRAINT road_segments_pkey PRIMARY KEY (id);


--
-- Name: weekly_predicted_crime weekly_predicted_crime_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.weekly_predicted_crime
    ADD CONSTRAINT weekly_predicted_crime_pkey PRIMARY KEY (id);


--
-- Name: idx_cell_risk_scores_cell_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cell_risk_scores_cell_id ON public.cell_risk_scores USING btree (cell_id);


--
-- Name: idx_crime_cell_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_crime_cell_id ON public.crime USING btree (cell_id);


--
-- Name: idx_crime_date_geom; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_crime_date_geom ON public.crime USING btree ("Date", geom);


--
-- Name: idx_crime_geom; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_crime_geom ON public.crime USING gist (geom);


--
-- Name: idx_crime_grid_daily_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_crime_grid_daily_date ON public.crime_grid_daily USING btree (date_only);


--
-- Name: idx_crime_grid_daily_grid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_crime_grid_daily_grid ON public.crime_grid_daily USING btree (grid_id);


--
-- Name: idx_crime_grid_daily_grid_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_crime_grid_daily_grid_date ON public.crime_grid_daily USING btree (grid_id, date_only);


--
-- Name: idx_crime_grid_weekly_grid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_crime_grid_weekly_grid ON public.crime_grid_weekly USING btree (grid_id);


--
-- Name: idx_crime_grid_weekly_grid_week; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_crime_grid_weekly_grid_week ON public.crime_grid_weekly USING btree (grid_id, week_start);


--
-- Name: idx_crime_grid_weekly_week; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_crime_grid_weekly_week ON public.crime_grid_weekly USING btree (week_start);


--
-- Name: idx_description; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_description ON public.crime USING btree ("Description");


--
-- Name: idx_grid_neighbors_grid_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_grid_neighbors_grid_id ON public.grid_neighbors USING btree (grid_id);


--
-- Name: idx_grid_neighbors_neighbor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_grid_neighbors_neighbor_id ON public.grid_neighbors USING btree (neighbor_grid_id);


--
-- Name: idx_lat_lon; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lat_lon ON public.crime USING btree ("Latitude", "Longitude");


--
-- Name: idx_nodes_geom; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_nodes_geom ON public.road_nodes USING gist (geometry);


--
-- Name: idx_primary_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_primary_type ON public.crime USING btree ("Primary Type");


--
-- Name: idx_road_nodes_geom; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_road_nodes_geom ON public.road_nodes USING gist (geometry);


--
-- Name: idx_road_nodes_geometry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_road_nodes_geometry ON public.road_nodes USING gist (geometry);


--
-- Name: idx_road_nodes_osmid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_road_nodes_osmid ON public.road_nodes USING btree (osmid);


--
-- Name: idx_road_segments_geom; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_road_segments_geom ON public.road_segments USING gist (geometry);


--
-- Name: idx_road_segments_geometry; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_road_segments_geometry ON public.road_segments USING gist (geometry);


--
-- Name: idx_road_segments_source; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_road_segments_source ON public.road_segments USING btree (source_node);


--
-- Name: idx_road_segments_target; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_road_segments_target ON public.road_segments USING btree (target_node);


--
-- Name: idx_rsgm_grid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rsgm_grid ON public.road_segment_grid_map USING btree (grid_cell_id);


--
-- Name: idx_rsgm_segment; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rsgm_segment ON public.road_segment_grid_map USING btree (road_segment_id);


--
-- Name: idx_segments_source_geom; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_segments_source_geom ON public.road_segments USING gist (source_geom);


--
-- Name: idx_segments_source_node; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_segments_source_node ON public.road_segments USING btree (source_node);


--
-- Name: idx_segments_target_geom; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_segments_target_geom ON public.road_segments USING gist (target_geom);


--
-- Name: idx_segments_target_node; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_segments_target_node ON public.road_segments USING btree (target_node);


--
-- Name: idx_weekly_predicted_crime_geom; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_weekly_predicted_crime_geom ON public.weekly_predicted_crime USING gist (geom);


--
-- Name: idx_weekly_predicted_crime_grid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_weekly_predicted_crime_grid ON public.weekly_predicted_crime USING btree (grid_id);


--
-- Name: idx_weekly_predicted_crime_week; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_weekly_predicted_crime_week ON public.weekly_predicted_crime USING btree (prediction_week_start);


--
-- Name: planet_osm_line_osm_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX planet_osm_line_osm_id_idx ON public.planet_osm_line USING btree (osm_id);


--
-- Name: planet_osm_line_way_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX planet_osm_line_way_idx ON public.planet_osm_line USING gist (way);


--
-- Name: planet_osm_point_osm_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX planet_osm_point_osm_id_idx ON public.planet_osm_point USING btree (osm_id);


--
-- Name: planet_osm_point_way_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX planet_osm_point_way_idx ON public.planet_osm_point USING gist (way);


--
-- Name: planet_osm_polygon_osm_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX planet_osm_polygon_osm_id_idx ON public.planet_osm_polygon USING btree (osm_id);


--
-- Name: planet_osm_polygon_way_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX planet_osm_polygon_way_idx ON public.planet_osm_polygon USING gist (way);


--
-- Name: planet_osm_rels_node_members_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX planet_osm_rels_node_members_idx ON public.planet_osm_rels USING gin (public.planet_osm_member_ids(members, 'N'::character(1))) WITH (fastupdate=off);


--
-- Name: planet_osm_rels_way_members_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX planet_osm_rels_way_members_idx ON public.planet_osm_rels USING gin (public.planet_osm_member_ids(members, 'W'::character(1))) WITH (fastupdate=off);


--
-- Name: planet_osm_roads_osm_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX planet_osm_roads_osm_id_idx ON public.planet_osm_roads USING btree (osm_id);


--
-- Name: planet_osm_roads_way_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX planet_osm_roads_way_idx ON public.planet_osm_roads USING gist (way);


--
-- Name: planet_osm_ways_nodes_bucket_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX planet_osm_ways_nodes_bucket_idx ON public.planet_osm_ways USING gin (public.planet_osm_index_bucket(nodes)) WITH (fastupdate=off);


--
-- Name: planet_osm_line planet_osm_line_osm2pgsql_valid; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER planet_osm_line_osm2pgsql_valid BEFORE INSERT OR UPDATE ON public.planet_osm_line FOR EACH ROW EXECUTE FUNCTION public.planet_osm_line_osm2pgsql_valid();


--
-- Name: planet_osm_point planet_osm_point_osm2pgsql_valid; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER planet_osm_point_osm2pgsql_valid BEFORE INSERT OR UPDATE ON public.planet_osm_point FOR EACH ROW EXECUTE FUNCTION public.planet_osm_point_osm2pgsql_valid();


--
-- Name: planet_osm_polygon planet_osm_polygon_osm2pgsql_valid; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER planet_osm_polygon_osm2pgsql_valid BEFORE INSERT OR UPDATE ON public.planet_osm_polygon FOR EACH ROW EXECUTE FUNCTION public.planet_osm_polygon_osm2pgsql_valid();


--
-- Name: planet_osm_roads planet_osm_roads_osm2pgsql_valid; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER planet_osm_roads_osm2pgsql_valid BEFORE INSERT OR UPDATE ON public.planet_osm_roads FOR EACH ROW EXECUTE FUNCTION public.planet_osm_roads_osm2pgsql_valid();


--
-- Name: road_segment_grid_map road_segment_grid_map_road_segment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.road_segment_grid_map
    ADD CONSTRAINT road_segment_grid_map_road_segment_id_fkey FOREIGN KEY (road_segment_id) REFERENCES public.road_segments(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict 8nb1qLNMUkffRgPeQ1PTCSMINnPKbCW90Be5DtCLHixFKOEXIWm1I8rf6eqDD3c

