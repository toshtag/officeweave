SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: btree_gist; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;


--
-- Name: EXTENSION btree_gist; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION btree_gist IS 'support for indexing common datatypes in GiST';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    service_name character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    variation_digest character varying NOT NULL
);


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_variant_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_variant_records_id_seq OWNED BY public.active_storage_variant_records.id;


--
-- Name: announcement_departments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.announcement_departments (
    id bigint NOT NULL,
    announcement_id bigint NOT NULL,
    department_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: announcement_departments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.announcement_departments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: announcement_departments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.announcement_departments_id_seq OWNED BY public.announcement_departments.id;


--
-- Name: announcement_reads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.announcement_reads (
    id bigint NOT NULL,
    announcement_id bigint NOT NULL,
    user_id bigint NOT NULL,
    read_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: announcement_reads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.announcement_reads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: announcement_reads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.announcement_reads_id_seq OWNED BY public.announcement_reads.id;


--
-- Name: announcements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.announcements (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    author_id bigint NOT NULL,
    title character varying NOT NULL,
    body text NOT NULL,
    visibility character varying DEFAULT 'organization'::character varying NOT NULL,
    published_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    notified_at timestamp(6) without time zone
);


--
-- Name: announcements_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.announcements_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: announcements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.announcements_id_seq OWNED BY public.announcements.id;


--
-- Name: api_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_tokens (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    user_id bigint NOT NULL,
    name character varying NOT NULL,
    token_digest character varying NOT NULL,
    last_used_at timestamp(6) without time zone,
    revoked_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    expires_at timestamp(6) without time zone,
    scopes character varying[]
);


--
-- Name: api_tokens_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.api_tokens_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: api_tokens_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.api_tokens_id_seq OWNED BY public.api_tokens.id;


--
-- Name: approval_steps; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.approval_steps (
    id bigint NOT NULL,
    request_type_id bigint NOT NULL,
    approver_department_id bigint,
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: approval_steps_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.approval_steps_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: approval_steps_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.approval_steps_id_seq OWNED BY public.approval_steps.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_events (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    actor_id bigint,
    action character varying NOT NULL,
    target_type character varying,
    target_id bigint,
    details jsonb DEFAULT '{}'::jsonb NOT NULL,
    ip_address character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: audit_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.audit_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audit_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.audit_events_id_seq OWNED BY public.audit_events.id;


--
-- Name: departments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.departments (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    parent_id bigint,
    name character varying NOT NULL,
    code character varying NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: departments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.departments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: departments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.departments_id_seq OWNED BY public.departments.id;


--
-- Name: document_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_categories (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    name character varying NOT NULL,
    code character varying NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: document_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.document_categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: document_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.document_categories_id_seq OWNED BY public.document_categories.id;


--
-- Name: document_departments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.document_departments (
    id bigint NOT NULL,
    document_id bigint NOT NULL,
    department_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: document_departments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.document_departments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: document_departments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.document_departments_id_seq OWNED BY public.document_departments.id;


--
-- Name: documents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.documents (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    document_category_id bigint,
    author_id bigint NOT NULL,
    title character varying NOT NULL,
    body text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    visibility character varying DEFAULT 'organization'::character varying NOT NULL
);


--
-- Name: documents_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.documents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: documents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.documents_id_seq OWNED BY public.documents.id;


--
-- Name: event_departments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.event_departments (
    id bigint NOT NULL,
    event_id bigint NOT NULL,
    department_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: event_departments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.event_departments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: event_departments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.event_departments_id_seq OWNED BY public.event_departments.id;


--
-- Name: events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.events (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    owner_id bigint NOT NULL,
    title character varying NOT NULL,
    description text,
    starts_at timestamp(6) without time zone NOT NULL,
    ends_at timestamp(6) without time zone NOT NULL,
    all_day boolean DEFAULT false NOT NULL,
    visibility character varying DEFAULT 'organization'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.events_id_seq OWNED BY public.events.id;


--
-- Name: memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.memberships (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    department_id bigint NOT NULL,
    "primary" boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: memberships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.memberships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: memberships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.memberships_id_seq OWNED BY public.memberships.id;


--
-- Name: notification_preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification_preferences (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    event character varying NOT NULL,
    mail_enabled boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: notification_preferences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notification_preferences_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notification_preferences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notification_preferences_id_seq OWNED BY public.notification_preferences.id;


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    subject_type character varying NOT NULL,
    subject_id bigint NOT NULL,
    event character varying NOT NULL,
    read_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.notifications_id_seq OWNED BY public.notifications.id;


--
-- Name: organizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organizations (
    id bigint NOT NULL,
    name character varying NOT NULL,
    code character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: organizations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.organizations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: organizations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.organizations_id_seq OWNED BY public.organizations.id;


--
-- Name: request_activities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.request_activities (
    id bigint NOT NULL,
    request_id bigint NOT NULL,
    actor_id bigint NOT NULL,
    action character varying NOT NULL,
    comment text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    step_position integer
);


--
-- Name: request_activities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.request_activities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: request_activities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.request_activities_id_seq OWNED BY public.request_activities.id;


--
-- Name: request_approval_steps; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.request_approval_steps (
    id bigint NOT NULL,
    request_id bigint NOT NULL,
    approver_department_id bigint,
    approver_id bigint,
    "position" integer DEFAULT 0 NOT NULL,
    approved_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: request_approval_steps_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.request_approval_steps_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: request_approval_steps_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.request_approval_steps_id_seq OWNED BY public.request_approval_steps.id;


--
-- Name: request_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.request_types (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    name character varying NOT NULL,
    code character varying NOT NULL,
    description text,
    active boolean DEFAULT true NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: request_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.request_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: request_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.request_types_id_seq OWNED BY public.request_types.id;


--
-- Name: requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.requests (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    request_type_id bigint NOT NULL,
    applicant_id bigint NOT NULL,
    title character varying NOT NULL,
    body text,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    submitted_at timestamp(6) without time zone,
    decided_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    current_step_position integer DEFAULT 10 NOT NULL
);


--
-- Name: requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.requests_id_seq OWNED BY public.requests.id;


--
-- Name: reservations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reservations (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    resource_id bigint NOT NULL,
    reserver_id bigint NOT NULL,
    event_id bigint,
    starts_at timestamp(6) without time zone NOT NULL,
    ends_at timestamp(6) without time zone NOT NULL,
    purpose character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: reservations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.reservations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reservations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.reservations_id_seq OWNED BY public.reservations.id;


--
-- Name: resources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.resources (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    name character varying NOT NULL,
    code character varying NOT NULL,
    description text,
    capacity integer,
    reservable boolean DEFAULT true NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: resources_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.resources_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: resources_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.resources_id_seq OWNED BY public.resources.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    ip_address character varying,
    user_agent character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    last_active_at timestamp(6) without time zone NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL
);


--
-- Name: sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sessions_id_seq OWNED BY public.sessions.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    name character varying NOT NULL,
    email_address character varying NOT NULL,
    password_digest character varying NOT NULL,
    locale character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    organization_id bigint NOT NULL,
    role character varying DEFAULT 'member'::character varying NOT NULL,
    deactivated_at timestamp(6) without time zone
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: webhook_deliveries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.webhook_deliveries (
    id bigint NOT NULL,
    webhook_endpoint_id bigint NOT NULL,
    event character varying NOT NULL,
    response_status integer,
    error_message character varying,
    delivered_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    failure_code character varying
);


--
-- Name: webhook_deliveries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.webhook_deliveries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: webhook_deliveries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.webhook_deliveries_id_seq OWNED BY public.webhook_deliveries.id;


--
-- Name: webhook_endpoints; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.webhook_endpoints (
    id bigint NOT NULL,
    organization_id bigint NOT NULL,
    name character varying NOT NULL,
    url character varying NOT NULL,
    secret character varying NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: webhook_endpoints_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.webhook_endpoints_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: webhook_endpoints_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.webhook_endpoints_id_seq OWNED BY public.webhook_endpoints.id;


--
-- Name: active_storage_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: active_storage_blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


--
-- Name: active_storage_variant_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records ALTER COLUMN id SET DEFAULT nextval('public.active_storage_variant_records_id_seq'::regclass);


--
-- Name: announcement_departments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcement_departments ALTER COLUMN id SET DEFAULT nextval('public.announcement_departments_id_seq'::regclass);


--
-- Name: announcement_reads id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcement_reads ALTER COLUMN id SET DEFAULT nextval('public.announcement_reads_id_seq'::regclass);


--
-- Name: announcements id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcements ALTER COLUMN id SET DEFAULT nextval('public.announcements_id_seq'::regclass);


--
-- Name: api_tokens id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_tokens ALTER COLUMN id SET DEFAULT nextval('public.api_tokens_id_seq'::regclass);


--
-- Name: approval_steps id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_steps ALTER COLUMN id SET DEFAULT nextval('public.approval_steps_id_seq'::regclass);


--
-- Name: audit_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events ALTER COLUMN id SET DEFAULT nextval('public.audit_events_id_seq'::regclass);


--
-- Name: departments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments ALTER COLUMN id SET DEFAULT nextval('public.departments_id_seq'::regclass);


--
-- Name: document_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_categories ALTER COLUMN id SET DEFAULT nextval('public.document_categories_id_seq'::regclass);


--
-- Name: document_departments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_departments ALTER COLUMN id SET DEFAULT nextval('public.document_departments_id_seq'::regclass);


--
-- Name: documents id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents ALTER COLUMN id SET DEFAULT nextval('public.documents_id_seq'::regclass);


--
-- Name: event_departments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_departments ALTER COLUMN id SET DEFAULT nextval('public.event_departments_id_seq'::regclass);


--
-- Name: events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events ALTER COLUMN id SET DEFAULT nextval('public.events_id_seq'::regclass);


--
-- Name: memberships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships ALTER COLUMN id SET DEFAULT nextval('public.memberships_id_seq'::regclass);


--
-- Name: notification_preferences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_preferences ALTER COLUMN id SET DEFAULT nextval('public.notification_preferences_id_seq'::regclass);


--
-- Name: notifications id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications ALTER COLUMN id SET DEFAULT nextval('public.notifications_id_seq'::regclass);


--
-- Name: organizations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations ALTER COLUMN id SET DEFAULT nextval('public.organizations_id_seq'::regclass);


--
-- Name: request_activities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.request_activities ALTER COLUMN id SET DEFAULT nextval('public.request_activities_id_seq'::regclass);


--
-- Name: request_approval_steps id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.request_approval_steps ALTER COLUMN id SET DEFAULT nextval('public.request_approval_steps_id_seq'::regclass);


--
-- Name: request_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.request_types ALTER COLUMN id SET DEFAULT nextval('public.request_types_id_seq'::regclass);


--
-- Name: requests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.requests ALTER COLUMN id SET DEFAULT nextval('public.requests_id_seq'::regclass);


--
-- Name: reservations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservations ALTER COLUMN id SET DEFAULT nextval('public.reservations_id_seq'::regclass);


--
-- Name: resources id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resources ALTER COLUMN id SET DEFAULT nextval('public.resources_id_seq'::regclass);


--
-- Name: sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions ALTER COLUMN id SET DEFAULT nextval('public.sessions_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: webhook_deliveries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_deliveries ALTER COLUMN id SET DEFAULT nextval('public.webhook_deliveries_id_seq'::regclass);


--
-- Name: webhook_endpoints id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_endpoints ALTER COLUMN id SET DEFAULT nextval('public.webhook_endpoints_id_seq'::regclass);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: announcement_departments announcement_departments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcement_departments
    ADD CONSTRAINT announcement_departments_pkey PRIMARY KEY (id);


--
-- Name: announcement_reads announcement_reads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcement_reads
    ADD CONSTRAINT announcement_reads_pkey PRIMARY KEY (id);


--
-- Name: announcements announcements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcements
    ADD CONSTRAINT announcements_pkey PRIMARY KEY (id);


--
-- Name: api_tokens api_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_tokens
    ADD CONSTRAINT api_tokens_pkey PRIMARY KEY (id);


--
-- Name: approval_steps approval_steps_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_steps
    ADD CONSTRAINT approval_steps_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: audit_events audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT audit_events_pkey PRIMARY KEY (id);


--
-- Name: departments departments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_pkey PRIMARY KEY (id);


--
-- Name: document_categories document_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_categories
    ADD CONSTRAINT document_categories_pkey PRIMARY KEY (id);


--
-- Name: document_departments document_departments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_departments
    ADD CONSTRAINT document_departments_pkey PRIMARY KEY (id);


--
-- Name: documents documents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_pkey PRIMARY KEY (id);


--
-- Name: event_departments event_departments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_departments
    ADD CONSTRAINT event_departments_pkey PRIMARY KEY (id);


--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- Name: memberships memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_pkey PRIMARY KEY (id);


--
-- Name: notification_preferences notification_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_preferences
    ADD CONSTRAINT notification_preferences_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: organizations organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (id);


--
-- Name: request_activities request_activities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.request_activities
    ADD CONSTRAINT request_activities_pkey PRIMARY KEY (id);


--
-- Name: request_approval_steps request_approval_steps_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.request_approval_steps
    ADD CONSTRAINT request_approval_steps_pkey PRIMARY KEY (id);


--
-- Name: request_types request_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.request_types
    ADD CONSTRAINT request_types_pkey PRIMARY KEY (id);


--
-- Name: requests requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.requests
    ADD CONSTRAINT requests_pkey PRIMARY KEY (id);


--
-- Name: reservations reservations_must_not_overlap; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservations
    ADD CONSTRAINT reservations_must_not_overlap EXCLUDE USING gist (resource_id WITH =, tsrange(starts_at, ends_at, '[)'::text) WITH &&);


--
-- Name: reservations reservations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservations
    ADD CONSTRAINT reservations_pkey PRIMARY KEY (id);


--
-- Name: resources resources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resources
    ADD CONSTRAINT resources_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: webhook_deliveries webhook_deliveries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_deliveries
    ADD CONSTRAINT webhook_deliveries_pkey PRIMARY KEY (id);


--
-- Name: webhook_endpoints webhook_endpoints_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_endpoints
    ADD CONSTRAINT webhook_endpoints_pkey PRIMARY KEY (id);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_announcement_departments_on_announcement_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_announcement_departments_on_announcement_id ON public.announcement_departments USING btree (announcement_id);


--
-- Name: index_announcement_departments_on_department_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_announcement_departments_on_department_id ON public.announcement_departments USING btree (department_id);


--
-- Name: index_announcement_departments_on_pair; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_announcement_departments_on_pair ON public.announcement_departments USING btree (announcement_id, department_id);


--
-- Name: index_announcement_reads_on_announcement_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_announcement_reads_on_announcement_id ON public.announcement_reads USING btree (announcement_id);


--
-- Name: index_announcement_reads_on_pair; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_announcement_reads_on_pair ON public.announcement_reads USING btree (announcement_id, user_id);


--
-- Name: index_announcement_reads_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_announcement_reads_on_user_id ON public.announcement_reads USING btree (user_id);


--
-- Name: index_announcements_on_author_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_announcements_on_author_id ON public.announcements USING btree (author_id);


--
-- Name: index_announcements_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_announcements_on_organization_id ON public.announcements USING btree (organization_id);


--
-- Name: index_announcements_on_organization_id_and_published_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_announcements_on_organization_id_and_published_at ON public.announcements USING btree (organization_id, published_at);


--
-- Name: index_announcements_on_published_at_and_notified_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_announcements_on_published_at_and_notified_at ON public.announcements USING btree (published_at, notified_at);


--
-- Name: index_api_tokens_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_api_tokens_on_organization_id ON public.api_tokens USING btree (organization_id);


--
-- Name: index_api_tokens_on_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_api_tokens_on_token_digest ON public.api_tokens USING btree (token_digest);


--
-- Name: index_api_tokens_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_api_tokens_on_user_id ON public.api_tokens USING btree (user_id);


--
-- Name: index_approval_steps_on_approver_department_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_approval_steps_on_approver_department_id ON public.approval_steps USING btree (approver_department_id);


--
-- Name: index_approval_steps_on_request_type_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_approval_steps_on_request_type_id ON public.approval_steps USING btree (request_type_id);


--
-- Name: index_approval_steps_on_request_type_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_approval_steps_on_request_type_id_and_position ON public.approval_steps USING btree (request_type_id, "position");


--
-- Name: index_audit_events_on_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_actor_id ON public.audit_events USING btree (actor_id);


--
-- Name: index_audit_events_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_organization_id ON public.audit_events USING btree (organization_id);


--
-- Name: index_audit_events_on_organization_id_and_action; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_organization_id_and_action ON public.audit_events USING btree (organization_id, action);


--
-- Name: index_audit_events_on_organization_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_organization_id_and_created_at ON public.audit_events USING btree (organization_id, created_at);


--
-- Name: index_audit_events_on_target_type_and_target_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_target_type_and_target_id ON public.audit_events USING btree (target_type, target_id);


--
-- Name: index_departments_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_departments_on_organization_id ON public.departments USING btree (organization_id);


--
-- Name: index_departments_on_organization_id_and_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_departments_on_organization_id_and_code ON public.departments USING btree (organization_id, code);


--
-- Name: index_departments_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_departments_on_parent_id ON public.departments USING btree (parent_id);


--
-- Name: index_document_categories_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_document_categories_on_organization_id ON public.document_categories USING btree (organization_id);


--
-- Name: index_document_categories_on_organization_id_and_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_document_categories_on_organization_id_and_code ON public.document_categories USING btree (organization_id, code);


--
-- Name: index_document_departments_on_department_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_document_departments_on_department_id ON public.document_departments USING btree (department_id);


--
-- Name: index_document_departments_on_document_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_document_departments_on_document_id ON public.document_departments USING btree (document_id);


--
-- Name: index_document_departments_on_pair; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_document_departments_on_pair ON public.document_departments USING btree (document_id, department_id);


--
-- Name: index_documents_on_author_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documents_on_author_id ON public.documents USING btree (author_id);


--
-- Name: index_documents_on_body_trigram; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documents_on_body_trigram ON public.documents USING gin (body public.gin_trgm_ops);


--
-- Name: index_documents_on_document_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documents_on_document_category_id ON public.documents USING btree (document_category_id);


--
-- Name: index_documents_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documents_on_organization_id ON public.documents USING btree (organization_id);


--
-- Name: index_documents_on_organization_id_and_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documents_on_organization_id_and_updated_at ON public.documents USING btree (organization_id, updated_at);


--
-- Name: index_documents_on_title_trigram; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_documents_on_title_trigram ON public.documents USING gin (title public.gin_trgm_ops);


--
-- Name: index_event_departments_on_department_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_event_departments_on_department_id ON public.event_departments USING btree (department_id);


--
-- Name: index_event_departments_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_event_departments_on_event_id ON public.event_departments USING btree (event_id);


--
-- Name: index_event_departments_on_pair; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_event_departments_on_pair ON public.event_departments USING btree (event_id, department_id);


--
-- Name: index_events_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_organization_id ON public.events USING btree (organization_id);


--
-- Name: index_events_on_organization_id_and_ends_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_organization_id_and_ends_at ON public.events USING btree (organization_id, ends_at);


--
-- Name: index_events_on_organization_id_and_starts_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_organization_id_and_starts_at ON public.events USING btree (organization_id, starts_at);


--
-- Name: index_events_on_owner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_owner_id ON public.events USING btree (owner_id);


--
-- Name: index_memberships_on_department_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_memberships_on_department_id ON public.memberships USING btree (department_id);


--
-- Name: index_memberships_on_primary_user; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_memberships_on_primary_user ON public.memberships USING btree (user_id) WHERE "primary";


--
-- Name: index_memberships_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_memberships_on_user_id ON public.memberships USING btree (user_id);


--
-- Name: index_memberships_on_user_id_and_department_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_memberships_on_user_id_and_department_id ON public.memberships USING btree (user_id, department_id);


--
-- Name: index_notification_preferences_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notification_preferences_on_user_id ON public.notification_preferences USING btree (user_id);


--
-- Name: index_notification_preferences_on_user_id_and_event; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_notification_preferences_on_user_id_and_event ON public.notification_preferences USING btree (user_id, event);


--
-- Name: index_notifications_on_subject; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_subject ON public.notifications USING btree (subject_type, subject_id);


--
-- Name: index_notifications_on_unread_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_unread_user_id ON public.notifications USING btree (user_id) WHERE (read_at IS NULL);


--
-- Name: index_notifications_on_user_and_subject_event; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_notifications_on_user_and_subject_event ON public.notifications USING btree (user_id, subject_type, subject_id, event);


--
-- Name: index_notifications_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_user_id ON public.notifications USING btree (user_id);


--
-- Name: index_notifications_on_user_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_notifications_on_user_id_and_created_at ON public.notifications USING btree (user_id, created_at);


--
-- Name: index_organizations_on_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_organizations_on_code ON public.organizations USING btree (code);


--
-- Name: index_request_activities_on_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_request_activities_on_actor_id ON public.request_activities USING btree (actor_id);


--
-- Name: index_request_activities_on_request_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_request_activities_on_request_id ON public.request_activities USING btree (request_id);


--
-- Name: index_request_activities_on_request_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_request_activities_on_request_id_and_created_at ON public.request_activities USING btree (request_id, created_at);


--
-- Name: index_request_approval_steps_on_approver_department_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_request_approval_steps_on_approver_department_id ON public.request_approval_steps USING btree (approver_department_id);


--
-- Name: index_request_approval_steps_on_approver_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_request_approval_steps_on_approver_id ON public.request_approval_steps USING btree (approver_id);


--
-- Name: index_request_approval_steps_on_request_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_request_approval_steps_on_request_id ON public.request_approval_steps USING btree (request_id);


--
-- Name: index_request_approval_steps_on_request_id_and_position; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_request_approval_steps_on_request_id_and_position ON public.request_approval_steps USING btree (request_id, "position");


--
-- Name: index_request_types_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_request_types_on_organization_id ON public.request_types USING btree (organization_id);


--
-- Name: index_request_types_on_organization_id_and_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_request_types_on_organization_id_and_code ON public.request_types USING btree (organization_id, code);


--
-- Name: index_requests_on_applicant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_requests_on_applicant_id ON public.requests USING btree (applicant_id);


--
-- Name: index_requests_on_applicant_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_requests_on_applicant_id_and_created_at ON public.requests USING btree (applicant_id, created_at);


--
-- Name: index_requests_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_requests_on_organization_id ON public.requests USING btree (organization_id);


--
-- Name: index_requests_on_organization_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_requests_on_organization_id_and_status ON public.requests USING btree (organization_id, status);


--
-- Name: index_requests_on_request_type_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_requests_on_request_type_id ON public.requests USING btree (request_type_id);


--
-- Name: index_reservations_on_event_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reservations_on_event_id ON public.reservations USING btree (event_id);


--
-- Name: index_reservations_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reservations_on_organization_id ON public.reservations USING btree (organization_id);


--
-- Name: index_reservations_on_organization_id_and_ends_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reservations_on_organization_id_and_ends_at ON public.reservations USING btree (organization_id, ends_at);


--
-- Name: index_reservations_on_reserver_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reservations_on_reserver_id ON public.reservations USING btree (reserver_id);


--
-- Name: index_reservations_on_resource_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reservations_on_resource_id ON public.reservations USING btree (resource_id);


--
-- Name: index_reservations_on_resource_id_and_starts_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reservations_on_resource_id_and_starts_at ON public.reservations USING btree (resource_id, starts_at);


--
-- Name: index_resources_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_resources_on_organization_id ON public.resources USING btree (organization_id);


--
-- Name: index_resources_on_organization_id_and_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_resources_on_organization_id_and_code ON public.resources USING btree (organization_id, code);


--
-- Name: index_sessions_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_expires_at ON public.sessions USING btree (expires_at);


--
-- Name: index_sessions_on_last_active_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_last_active_at ON public.sessions USING btree (last_active_at);


--
-- Name: index_sessions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_user_id ON public.sessions USING btree (user_id);


--
-- Name: index_users_on_deactivated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_deactivated_at ON public.users USING btree (deactivated_at);


--
-- Name: index_users_on_email_address; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email_address ON public.users USING btree (email_address);


--
-- Name: index_users_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_organization_id ON public.users USING btree (organization_id);


--
-- Name: index_users_on_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_role ON public.users USING btree (role);


--
-- Name: index_webhook_deliveries_on_webhook_endpoint_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_webhook_deliveries_on_webhook_endpoint_id ON public.webhook_deliveries USING btree (webhook_endpoint_id);


--
-- Name: index_webhook_deliveries_on_webhook_endpoint_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_webhook_deliveries_on_webhook_endpoint_id_and_created_at ON public.webhook_deliveries USING btree (webhook_endpoint_id, created_at);


--
-- Name: index_webhook_endpoints_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_webhook_endpoints_on_organization_id ON public.webhook_endpoints USING btree (organization_id);


--
-- Name: announcements fk_rails_092f822a9d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcements
    ADD CONSTRAINT fk_rails_092f822a9d FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: reservations fk_rails_13b11538cb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservations
    ADD CONSTRAINT fk_rails_13b11538cb FOREIGN KEY (resource_id) REFERENCES public.resources(id);


--
-- Name: events fk_rails_163b5130b5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT fk_rails_163b5130b5 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: webhook_endpoints fk_rails_21808fa528; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_endpoints
    ADD CONSTRAINT fk_rails_21808fa528 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: request_types fk_rails_22236c1ac1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.request_types
    ADD CONSTRAINT fk_rails_22236c1ac1 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: documents fk_rails_38b1cebf1f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT fk_rails_38b1cebf1f FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: webhook_deliveries fk_rails_392378d371; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_deliveries
    ADD CONSTRAINT fk_rails_392378d371 FOREIGN KEY (webhook_endpoint_id) REFERENCES public.webhook_endpoints(id);


--
-- Name: announcement_reads fk_rails_3bf795c88f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcement_reads
    ADD CONSTRAINT fk_rails_3bf795c88f FOREIGN KEY (announcement_id) REFERENCES public.announcements(id);


--
-- Name: request_approval_steps fk_rails_5450b5e294; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.request_approval_steps
    ADD CONSTRAINT fk_rails_5450b5e294 FOREIGN KEY (request_id) REFERENCES public.requests(id);


--
-- Name: requests fk_rails_54d15c43d3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.requests
    ADD CONSTRAINT fk_rails_54d15c43d3 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: requests fk_rails_59d5c2771d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.requests
    ADD CONSTRAINT fk_rails_59d5c2771d FOREIGN KEY (request_type_id) REFERENCES public.request_types(id);


--
-- Name: request_approval_steps fk_rails_5c3bd45f9c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.request_approval_steps
    ADD CONSTRAINT fk_rails_5c3bd45f9c FOREIGN KEY (approver_department_id) REFERENCES public.departments(id);


--
-- Name: document_departments fk_rails_6323f47c20; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_departments
    ADD CONSTRAINT fk_rails_6323f47c20 FOREIGN KEY (document_id) REFERENCES public.documents(id);


--
-- Name: api_tokens fk_rails_701d89e8df; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_tokens
    ADD CONSTRAINT fk_rails_701d89e8df FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: sessions fk_rails_758836b4f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_758836b4f0 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: request_activities fk_rails_78aa323dc9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.request_activities
    ADD CONSTRAINT fk_rails_78aa323dc9 FOREIGN KEY (actor_id) REFERENCES public.users(id);


--
-- Name: announcement_departments fk_rails_7aa82a34b1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcement_departments
    ADD CONSTRAINT fk_rails_7aa82a34b1 FOREIGN KEY (department_id) REFERENCES public.departments(id);


--
-- Name: document_categories fk_rails_8442905ffc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_categories
    ADD CONSTRAINT fk_rails_8442905ffc FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: event_departments fk_rails_8c9c119949; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_departments
    ADD CONSTRAINT fk_rails_8c9c119949 FOREIGN KEY (event_id) REFERENCES public.events(id);


--
-- Name: departments fk_rails_8e1e5764fc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT fk_rails_8e1e5764fc FOREIGN KEY (parent_id) REFERENCES public.departments(id);


--
-- Name: departments fk_rails_94440b0e8f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT fk_rails_94440b0e8f FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: notification_preferences fk_rails_9503aade25; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_preferences
    ADD CONSTRAINT fk_rails_9503aade25 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: documents fk_rails_98ed785f39; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT fk_rails_98ed785f39 FOREIGN KEY (author_id) REFERENCES public.users(id);


--
-- Name: memberships fk_rails_99326fb65d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT fk_rails_99326fb65d FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: announcements fk_rails_994ada01bd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcements
    ADD CONSTRAINT fk_rails_994ada01bd FOREIGN KEY (author_id) REFERENCES public.users(id);


--
-- Name: event_departments fk_rails_9a55143380; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_departments
    ADD CONSTRAINT fk_rails_9a55143380 FOREIGN KEY (department_id) REFERENCES public.departments(id);


--
-- Name: memberships fk_rails_9ce98a6ecb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT fk_rails_9ce98a6ecb FOREIGN KEY (department_id) REFERENCES public.departments(id);


--
-- Name: approval_steps fk_rails_a7428c09ac; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_steps
    ADD CONSTRAINT fk_rails_a7428c09ac FOREIGN KEY (request_type_id) REFERENCES public.request_types(id);


--
-- Name: reservations fk_rails_af7a37539f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservations
    ADD CONSTRAINT fk_rails_af7a37539f FOREIGN KEY (event_id) REFERENCES public.events(id);


--
-- Name: notifications fk_rails_b080fb4855; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT fk_rails_b080fb4855 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: reservations fk_rails_b79e7e2f37; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservations
    ADD CONSTRAINT fk_rails_b79e7e2f37 FOREIGN KEY (reserver_id) REFERENCES public.users(id);


--
-- Name: resources fk_rails_b7c74d1aaf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.resources
    ADD CONSTRAINT fk_rails_b7c74d1aaf FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: audit_events fk_rails_be0ed9e37f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT fk_rails_be0ed9e37f FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: reservations fk_rails_bf8a5a02cd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservations
    ADD CONSTRAINT fk_rails_bf8a5a02cd FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: request_activities fk_rails_d0a33336f3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.request_activities
    ADD CONSTRAINT fk_rails_d0a33336f3 FOREIGN KEY (request_id) REFERENCES public.requests(id);


--
-- Name: users fk_rails_d7b9ff90af; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_rails_d7b9ff90af FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: requests fk_rails_dbfac71f2d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.requests
    ADD CONSTRAINT fk_rails_dbfac71f2d FOREIGN KEY (applicant_id) REFERENCES public.users(id);


--
-- Name: audit_events fk_rails_dd1f3a471a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT fk_rails_dd1f3a471a FOREIGN KEY (actor_id) REFERENCES public.users(id);


--
-- Name: approval_steps fk_rails_e628977c60; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_steps
    ADD CONSTRAINT fk_rails_e628977c60 FOREIGN KEY (approver_department_id) REFERENCES public.departments(id);


--
-- Name: document_departments fk_rails_e676903eef; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.document_departments
    ADD CONSTRAINT fk_rails_e676903eef FOREIGN KEY (department_id) REFERENCES public.departments(id);


--
-- Name: request_approval_steps fk_rails_e724329876; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.request_approval_steps
    ADD CONSTRAINT fk_rails_e724329876 FOREIGN KEY (approver_id) REFERENCES public.users(id);


--
-- Name: announcement_reads fk_rails_e929ca5a13; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcement_reads
    ADD CONSTRAINT fk_rails_e929ca5a13 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: documents fk_rails_f078ae7115; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT fk_rails_f078ae7115 FOREIGN KEY (document_category_id) REFERENCES public.document_categories(id);


--
-- Name: api_tokens fk_rails_f16b5e0447; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_tokens
    ADD CONSTRAINT fk_rails_f16b5e0447 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: events fk_rails_f58490957c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT fk_rails_f58490957c FOREIGN KEY (owner_id) REFERENCES public.users(id);


--
-- Name: announcement_departments fk_rails_f704ebbc74; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.announcement_departments
    ADD CONSTRAINT fk_rails_f704ebbc74 FOREIGN KEY (announcement_id) REFERENCES public.announcements(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260803030000'),
('20260803020000'),
('20260803010000'),
('20260803000000'),
('20260802020000'),
('20260802010000'),
('20260802000000'),
('20260801000000'),
('20260731000000'),
('20260730000000'),
('20260729084654'),
('20260729083323'),
('20260729083322'),
('20260729082901'),
('20260729082553'),
('20260729081815'),
('20260729081505'),
('20260729081128'),
('20260729081127'),
('20260729080718'),
('20260729080438'),
('20260729080437'),
('20260729075745'),
('20260729075216'),
('20260729075215'),
('20260729074307'),
('20260729074049'),
('20260729073655'),
('20260729073654'),
('20260729073437'),
('20260729073024'),
('20260729073023'),
('20260729072358'),
('20260729072056'),
('20260729071341'),
('20260729071340'),
('20260729071339'),
('20260729071338'),
('20260729070422'),
('20260729070421');

