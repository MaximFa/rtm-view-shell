-- FIXTURE for PR234-CMP-01 part 1 (corpus symmetry). REAL pg_dump output, not hand-written.
-- Produced 2026-09-19 by devops-0916: pg_dump (PostgreSQL) 16.13, --schema-only --no-owner --no-acl -n public,
-- from a throwaway database: 2 whitelisted tables, 2 FUNCTIONs and 1 PROCEDURE whose bodies reference the
-- business-unit table. ONE function has a BLANK LINE inside its body, and the reference comes AFTER it -
-- the case (coordinator-0917, 19.09) that a filter keyed on a block's first statement cannot see.
-- NOTE: this header names NO quoted table on purpose: a quoted whitelist name here made the filter keep
-- THIS COMMENT as a table block. Any edit to this file must be followed by re-measuring.
-- LIMIT: server 234 runs PostgreSQL 18; this layout is confirmed there only by the live acceptance.

--
-- PostgreSQL database dump
--

\restrict KqWPHFqT0EXYisEelqYaHhvO0cxjwmnQEOT37nUJ1ehdSTC8Bk4ggFpRREaXMkF

-- Dumped from database version 16.13 (Ubuntu 16.13-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.13 (Ubuntu 16.13-0ubuntu0.24.04.1)

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
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: NGC_DeleteBusinessUnit(integer, uuid); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public."NGC_DeleteBusinessUnit"(IN p_id integer, IN p_tenant_id uuid)
    LANGUAGE plpgsql
    AS $$
BEGIN
  DELETE FROM public."NGC_BusinessUnit" WHERE "BusinessUnitID" = p_id AND tenant_id = p_tenant_id;
END $$;


--
-- Name: NGC_GetBusinessUnitTable(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."NGC_GetBusinessUnitTable"(p_tenant_id uuid) RETURNS TABLE("BusinessUnitID" integer, "Name" text)
    LANGUAGE sql
    AS $$
  SELECT "BusinessUnitID", "Name" FROM public."NGC_BusinessUnit" WHERE tenant_id = p_tenant_id
$$;


--
-- Name: NGC_GetSiteTable(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public."NGC_GetSiteTable"(p_tenant_id uuid) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE v_count integer;
BEGIN
  v_count := 0;

  SELECT count(*) INTO v_count FROM public."NGC_BusinessUnit" WHERE tenant_id = p_tenant_id;
  RETURN v_count;
END $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: NGC_BusinessUnit; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."NGC_BusinessUnit" (
    "BusinessUnitID" integer NOT NULL,
    "Name" text NOT NULL,
    tenant_id uuid
);


--
-- Name: NGC_BusinessUnitSupergroup; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."NGC_BusinessUnitSupergroup" (
    "BusinessUnitID" integer,
    "SupergroupID" integer
);


--
-- Name: NGC_BusinessUnit_BusinessUnitID_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."NGC_BusinessUnit_BusinessUnitID_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: NGC_BusinessUnit_BusinessUnitID_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."NGC_BusinessUnit_BusinessUnitID_seq" OWNED BY public."NGC_BusinessUnit"."BusinessUnitID";


--
-- Name: NGC_BusinessUnit BusinessUnitID; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NGC_BusinessUnit" ALTER COLUMN "BusinessUnitID" SET DEFAULT nextval('public."NGC_BusinessUnit_BusinessUnitID_seq"'::regclass);


--
-- Name: NGC_BusinessUnit NGC_BusinessUnit_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NGC_BusinessUnit"
    ADD CONSTRAINT "NGC_BusinessUnit_pkey" PRIMARY KEY ("BusinessUnitID");


--
-- PostgreSQL database dump complete
--

\unrestrict KqWPHFqT0EXYisEelqYaHhvO0cxjwmnQEOT37nUJ1ehdSTC8Bk4ggFpRREaXMkF

