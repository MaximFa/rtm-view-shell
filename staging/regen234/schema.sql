--
-- PostgreSQL database dump
--

-- Dumped from database version 15.5
-- Dumped by pg_dump version 15.5

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
-- Name: db_patch_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.db_patch_history (
    migration_name text NOT NULL,
    applied_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: metric_deploy_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.metric_deploy_log (
    "MetricId" text NOT NULL,
    "DeployedAt" timestamp with time zone NOT NULL,
    "SourceCommit" text
);


--
-- Name: db_patch_history db_patch_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.db_patch_history
    ADD CONSTRAINT db_patch_history_pkey PRIMARY KEY (migration_name);


--
-- Name: metric_deploy_log metric_deploy_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.metric_deploy_log
    ADD CONSTRAINT metric_deploy_log_pkey PRIMARY KEY ("MetricId");


--
-- PostgreSQL database dump complete
--

