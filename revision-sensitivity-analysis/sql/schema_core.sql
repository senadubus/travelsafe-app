--
-- PostgreSQL database dump
--

\restrict rDHkjANt93VB33OhjjLygDRpaLrKj7PRPfKAWMYld38TZc70MXlNRRQXXWp8ZpD

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
-- Name: crime id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crime ALTER COLUMN id SET DEFAULT nextval('public.crime_id_seq'::regclass);


--
-- Name: grid_cells id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grid_cells ALTER COLUMN id SET DEFAULT nextval('public.grid_cells_id_seq'::regclass);


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
-- Name: grid_cells grid_cells_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.grid_cells
    ADD CONSTRAINT grid_cells_pkey PRIMARY KEY (id);


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
-- Name: road_segment_grid_map road_segment_grid_map_road_segment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.road_segment_grid_map
    ADD CONSTRAINT road_segment_grid_map_road_segment_id_fkey FOREIGN KEY (road_segment_id) REFERENCES public.road_segments(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict rDHkjANt93VB33OhjjLygDRpaLrKj7PRPfKAWMYld38TZc70MXlNRRQXXWp8ZpD

