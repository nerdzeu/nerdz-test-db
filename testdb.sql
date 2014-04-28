--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


SET search_path = public, pg_catalog;

--
-- Name: after_delete_blacklist(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION after_delete_blacklist() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

    BEGIN
    
        DELETE FROM "posts_no_notify" WHERE "user" = OLD."to" AND (
            "hpid" IN (
            
                SELECT "hpid"  FROM "posts" WHERE "from" = OLD."to" AND "to" = OLD."from"
                
            ) OR "hpid" IN (
            
                SELECT "hpid"  FROM "comments" WHERE "from" = OLD."to" AND "to" = OLD."from"
                
            )
        );
        
        RETURN OLD;
        
    END

$$;


ALTER FUNCTION public.after_delete_blacklist() OWNER TO test_db;

--
-- Name: before_delete_group(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION before_delete_group() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

    BEGIN 

        DELETE FROM "groups_comments" WHERE "to" = OLD."counter"; 
        
        DELETE FROM "groups_comments_no_notify" WHERE "hpid" IN (
            SELECT "hpid" FROM "groups_posts" WHERE "to" = OLD."counter"
        ); 
        
        DELETE FROM "groups_comments_notify" WHERE "hpid" IN (
            SELECT "hpid" FROM "groups_posts" WHERE "to" = OLD."counter"
        ); 
        
        DELETE FROM "groups_followers" WHERE "group" = OLD."counter"; 
        
        DELETE FROM "groups_lurkers" WHERE "post" IN (
            SELECT "hpid" FROM "groups_posts" WHERE "to" = OLD."counter"
        );
        
        DELETE FROM "groups_members" WHERE "group" = OLD."counter";
        
        DELETE FROM "groups_notify" WHERE "group" = OLD."counter";
        
        DELETE FROM "groups_posts_no_notify" WHERE "hpid" IN (
            SELECT "hpid" FROM "groups_posts" WHERE "to" = OLD."counter"
        );
        
        DELETE FROM "groups_posts" WHERE "to" = OLD."counter";
        
        RETURN OLD;

    END

$$;


ALTER FUNCTION public.before_delete_group() OWNER TO test_db;

--
-- Name: before_delete_groups_posts(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION before_delete_groups_posts() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

    BEGIN
    
        DELETE FROM "groups_comments" WHERE "hpid" = OLD.hpid;
        
        DELETE FROM "groups_comments_notify" WHERE "hpid" = OLD.hpid;
        
        DELETE FROM "groups_comments_no_notify" WHERE "hpid" = OLD.hpid;
        
        DELETE FROM "groups_posts_no_notify" WHERE "hpid" = OLD.hpid;
        
        DELETE FROM "groups_lurkers" WHERE "post" = OLD.hpid;
        
        DELETE FROM "groups_bookmarks" WHERE "hpid" = OLD.hpid;
        
        RETURN OLD;
        
    END

$$;


ALTER FUNCTION public.before_delete_groups_posts() OWNER TO test_db;

--
-- Name: before_delete_post(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION before_delete_post() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

    BEGIN
    
        DELETE FROM "comments" WHERE "hpid" = OLD.hpid;
        
        DELETE FROM "comments_notify" WHERE "hpid" = OLD.hpid;
        
        DELETE FROM "comments_no_notify" WHERE "hpid" = OLD.hpid;
        
        DELETE FROM "posts_no_notify" WHERE "hpid" = OLD.hpid;
        
        DELETE FROM "lurkers" WHERE "post" = OLD.hpid;
        
        DELETE FROM "bookmarks" WHERE "hpid" = OLD.hpid;
        
        RETURN OLD;
        
    END

$$;


ALTER FUNCTION public.before_delete_post() OWNER TO test_db;

--
-- Name: before_delete_user(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION before_delete_user() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

    BEGIN
    
        DELETE FROM "blacklist" WHERE "from" = OLD.counter OR "to" = OLD.counter;
        DELETE FROM "whitelist" WHERE "from" = OLD.counter OR "to" = OLD.counter;
        DELETE FROM "lurkers" WHERE "user" = OLD.counter;
        DELETE FROM "groups_lurkers" WHERE "user" = OLD.counter;
        DELETE FROM "closed_profiles" WHERE "counter" = OLD.counter;
        DELETE FROM "follow" WHERE "from" = OLD.counter OR "to" = OLD.counter;
        DELETE FROM "groups_followers" WHERE "user" = OLD.counter;
        DELETE FROM "groups_members" WHERE "user" = OLD.counter;
        DELETE FROM "pms" WHERE "from" = OLD.counter OR "to" = OLD.counter;

        DELETE FROM "bookmarks" WHERE "from" = OLD.counter;
        DELETE FROM "groups_bookmarks" WHERE "from" = OLD.counter;

        DELETE FROM "posts" WHERE "to" = OLD.counter;
        
        UPDATE "posts" SET "from" = 1644 WHERE "from" = OLD.counter;

        UPDATE "comments" SET "from" = 1644 WHERE "from" = OLD.counter;
        
        DELETE FROM "comments" WHERE "to" = OLD.counter;
        DELETE FROM "comments_no_notify" WHERE "from" = OLD.counter OR "to" = OLD.counter;
        DELETE FROM "comments_notify" WHERE "from" = OLD.counter OR "to" = OLD.counter;

        UPDATE "groups_comments" SET "from" = 1644 WHERE "from" = OLD.counter;
        
        DELETE FROM "groups_comments_no_notify" WHERE "from" = OLD.counter OR "to" = OLD.counter;
        DELETE FROM "groups_comments_notify" WHERE "from" = OLD.counter OR "to" = OLD.counter;

        DELETE FROM "groups_notify" WHERE "to" = OLD.counter;
        
        UPDATE "groups_posts" SET "from" = 1644 WHERE "from" = OLD.counter;
        
        DELETE FROM "groups_posts_no_notify" WHERE "user" = OLD.counter;

        DELETE FROM "posts_no_notify" WHERE "user" = OLD.counter;

        UPDATE "groups" SET "owner" = 1644 WHERE "owner" = OLD.counter;
        
        DELETE FROM "profiles" WHERE "counter" = OLD.counter;
        
        RETURN OLD;
        
    END

$$;


ALTER FUNCTION public.before_delete_user() OWNER TO test_db;

--
-- Name: before_insert_blacklist(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION before_insert_blacklist() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

    BEGIN

        DELETE FROM posts_no_notify WHERE ("user", "hpid") IN (
            SELECT "to", "hpid" FROM ((
            
                    SELECT NEW."to", "hpid", NOW() FROM "posts" WHERE "from" = NEW."to" AND "to" = NEW."from"
                    
                ) UNION DISTINCT (
                
                    SELECT NEW."to", "hpid", NOW() FROM "comments" WHERE "from" = NEW."to" AND "to" = NEW."from"
                    
                )
            ) AS TMP_B1
        );

        INSERT INTO posts_no_notify("user","hpid","time") (
        
            SELECT NEW."to", "hpid", NOW() FROM "posts" WHERE "from" = NEW."to" AND "to" = NEW."from"
            
        ) UNION DISTINCT (
        
            SELECT NEW."to", "hpid", NOW() FROM "comments" WHERE "from" = NEW."to" AND "to" = NEW."from"
            
        );

        DELETE FROM "follow" WHERE ("from" = NEW."from" AND "to" = NEW."to") OR ("to" = NEW."from" AND "from" = NEW."to");
        
        RETURN NEW;
        
    END

$$;


ALTER FUNCTION public.before_insert_blacklist() OWNER TO test_db;

--
-- Name: before_insert_on_groups_lurkers(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION before_insert_on_groups_lurkers() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

    BEGIN 
    
        IF ( 
            NEW.user IN (
                SELECT "from" FROM "groups_comments" WHERE hpid = NEW.post
            )
        ) THEN 
            RAISE EXCEPTION 'Can''t lurk if just posted'; 
        END IF; 
        
        RETURN NEW;

    END

$$;


ALTER FUNCTION public.before_insert_on_groups_lurkers() OWNER TO test_db;

--
-- Name: before_insert_on_lurkers(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION before_insert_on_lurkers() RETURNS trigger
    LANGUAGE plpgsql
    AS $$

    BEGIN
    
        IF (
            NEW.user IN (
            
                SELECT "from" FROM "comments" WHERE hpid = NEW.post
                
            )
        ) THEN
            RAISE EXCEPTION 'Can''t lurk if just posted';
        END IF;
        
        RETURN NEW;
        
    END

$$;


ALTER FUNCTION public.before_insert_on_lurkers() OWNER TO test_db;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: ban; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE ban (
    "user" bigint NOT NULL,
    motivation text DEFAULT 'No reason given'::text NOT NULL
);


ALTER TABLE public.ban OWNER TO test_db;

--
-- Name: blacklist; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE blacklist (
    "from" bigint NOT NULL,
    "to" bigint NOT NULL,
    motivation text DEFAULT 'No reason given'::text
);


ALTER TABLE public.blacklist OWNER TO test_db;

--
-- Name: bookmarks; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE bookmarks (
    "from" bigint NOT NULL,
    hpid bigint NOT NULL,
    "time" timestamp(0) with time zone NOT NULL,
    CONSTRAINT bookmarkstimecheck CHECK ((date_part('timezone'::text, "time") = 0::double precision))
);


ALTER TABLE public.bookmarks OWNER TO test_db;

--
-- Name: closed_profiles; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE closed_profiles (
    counter bigint NOT NULL
);


ALTER TABLE public.closed_profiles OWNER TO test_db;

--
-- Name: comment_thumbs; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE comment_thumbs (
    hcid bigint NOT NULL,
    "user" bigint NOT NULL,
    vote smallint NOT NULL,
    CONSTRAINT chkvote CHECK ((vote = ANY (ARRAY[(-1), 0, 1])))
);


ALTER TABLE public.comment_thumbs OWNER TO test_db;

--
-- Name: comments; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE comments (
    "from" bigint NOT NULL,
    "to" bigint NOT NULL,
    hpid bigint NOT NULL,
    message text NOT NULL,
    "time" timestamp(0) with time zone NOT NULL,
    hcid bigint NOT NULL,
    CONSTRAINT commentstimecheck CHECK ((date_part('timezone'::text, "time") = 0::double precision))
);


ALTER TABLE public.comments OWNER TO test_db;

--
-- Name: comments_hcid_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE comments_hcid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.comments_hcid_seq OWNER TO test_db;

--
-- Name: comments_hcid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE comments_hcid_seq OWNED BY comments.hcid;


--
-- Name: comments_no_notify; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE comments_no_notify (
    "from" bigint NOT NULL,
    "to" bigint NOT NULL,
    hpid bigint NOT NULL,
    "time" timestamp(0) with time zone NOT NULL,
    CONSTRAINT commentsnonotifytimecheck CHECK ((date_part('timezone'::text, "time") = 0::double precision))
);


ALTER TABLE public.comments_no_notify OWNER TO test_db;

--
-- Name: comments_notify; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE comments_notify (
    "from" bigint NOT NULL,
    "to" bigint NOT NULL,
    hpid bigint NOT NULL,
    "time" timestamp(0) with time zone NOT NULL,
    CONSTRAINT commentsnotifytimecheck CHECK ((date_part('timezone'::text, "time") = 0::double precision))
);


ALTER TABLE public.comments_notify OWNER TO test_db;

--
-- Name: follow; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE follow (
    "from" bigint NOT NULL,
    "to" bigint NOT NULL,
    notified boolean DEFAULT true,
    "time" timestamp(0) with time zone NOT NULL,
    CONSTRAINT followtimecheck CHECK ((date_part('timezone'::text, "time") = 0::double precision))
);


ALTER TABLE public.follow OWNER TO test_db;

--
-- Name: groups; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE groups (
    counter bigint NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    owner bigint,
    name character varying(30) NOT NULL,
    private boolean DEFAULT false NOT NULL,
    photo character varying(350) DEFAULT NULL::character varying,
    website character varying(350) DEFAULT NULL::character varying,
    goal text DEFAULT ''::text NOT NULL,
    visible boolean DEFAULT true NOT NULL,
    open boolean DEFAULT false NOT NULL
);


ALTER TABLE public.groups OWNER TO test_db;

--
-- Name: groups_bookmarks; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE groups_bookmarks (
    "from" bigint NOT NULL,
    hpid bigint NOT NULL,
    "time" timestamp(0) with time zone NOT NULL
);


ALTER TABLE public.groups_bookmarks OWNER TO test_db;

--
-- Name: groups_comment_thumbs; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE groups_comment_thumbs (
    hcid bigint NOT NULL,
    "user" bigint NOT NULL,
    vote smallint NOT NULL,
    CONSTRAINT chkgvote CHECK ((vote = ANY (ARRAY[(-1), 0, 1])))
);


ALTER TABLE public.groups_comment_thumbs OWNER TO test_db;

--
-- Name: groups_comments; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE groups_comments (
    "from" bigint NOT NULL,
    "to" bigint NOT NULL,
    hpid bigint NOT NULL,
    message text NOT NULL,
    "time" timestamp(0) with time zone NOT NULL,
    hcid bigint NOT NULL,
    CONSTRAINT groupscommentstimecheck CHECK ((date_part('timezone'::text, "time") = 0::double precision))
);


ALTER TABLE public.groups_comments OWNER TO test_db;

--
-- Name: groups_comments_hcid_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE groups_comments_hcid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.groups_comments_hcid_seq OWNER TO test_db;

--
-- Name: groups_comments_hcid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE groups_comments_hcid_seq OWNED BY groups_comments.hcid;


--
-- Name: groups_comments_no_notify; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE groups_comments_no_notify (
    "from" bigint NOT NULL,
    "to" bigint NOT NULL,
    hpid bigint NOT NULL,
    "time" timestamp(0) with time zone NOT NULL,
    CONSTRAINT groupscommentsnonotifytimecheck CHECK ((date_part('timezone'::text, "time") = 0::double precision))
);


ALTER TABLE public.groups_comments_no_notify OWNER TO test_db;

--
-- Name: groups_comments_notify; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE groups_comments_notify (
    "from" bigint NOT NULL,
    "to" bigint NOT NULL,
    hpid bigint NOT NULL,
    "time" timestamp(0) with time zone NOT NULL,
    CONSTRAINT groupscommentsnonotifytimecheck CHECK ((date_part('timezone'::text, "time") = 0::double precision))
);


ALTER TABLE public.groups_comments_notify OWNER TO test_db;

--
-- Name: groups_counter_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE groups_counter_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.groups_counter_seq OWNER TO test_db;

--
-- Name: groups_counter_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE groups_counter_seq OWNED BY groups.counter;


--
-- Name: groups_followers; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE groups_followers (
    "group" bigint NOT NULL,
    "user" bigint NOT NULL
);


ALTER TABLE public.groups_followers OWNER TO test_db;

--
-- Name: groups_lurkers; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE groups_lurkers (
    "user" bigint NOT NULL,
    post bigint NOT NULL,
    "time" timestamp(0) with time zone NOT NULL,
    CONSTRAINT groupslurkerstimecheck CHECK ((date_part('timezone'::text, "time") = 0::double precision))
);


ALTER TABLE public.groups_lurkers OWNER TO test_db;

--
-- Name: groups_members; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE groups_members (
    "group" bigint NOT NULL,
    "user" bigint NOT NULL
);


ALTER TABLE public.groups_members OWNER TO test_db;

--
-- Name: groups_notify; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE groups_notify (
    "group" bigint NOT NULL,
    "to" bigint NOT NULL,
    "time" timestamp(0) with time zone NOT NULL,
    CONSTRAINT groupsnotifytimecheck CHECK ((date_part('timezone'::text, "time") = 0::double precision))
);


ALTER TABLE public.groups_notify OWNER TO test_db;

--
-- Name: groups_posts; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE groups_posts (
    hpid bigint NOT NULL,
    "from" bigint NOT NULL,
    "to" bigint NOT NULL,
    pid bigint NOT NULL,
    message text NOT NULL,
    "time" timestamp(0) with time zone NOT NULL,
    news boolean DEFAULT false NOT NULL,
    CONSTRAINT groupspoststimecheck CHECK ((date_part('timezone'::text, "time") = 0::double precision))
);


ALTER TABLE public.groups_posts OWNER TO test_db;

--
-- Name: groups_posts_hpid_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE groups_posts_hpid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.groups_posts_hpid_seq OWNER TO test_db;

--
-- Name: groups_posts_hpid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE groups_posts_hpid_seq OWNED BY groups_posts.hpid;


--
-- Name: groups_posts_no_notify; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE groups_posts_no_notify (
    "user" bigint NOT NULL,
    hpid bigint NOT NULL,
    "time" timestamp(0) with time zone NOT NULL,
    CONSTRAINT groupspostsnonotifytimecheck CHECK ((date_part('timezone'::text, "time") = 0::double precision))
);


ALTER TABLE public.groups_posts_no_notify OWNER TO test_db;

--
-- Name: groups_thumbs; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE groups_thumbs (
    hpid bigint NOT NULL,
    "user" bigint NOT NULL,
    vote smallint NOT NULL,
    CONSTRAINT chkgvote CHECK ((vote = ANY (ARRAY[(-1), 0, 1])))
);


ALTER TABLE public.groups_thumbs OWNER TO test_db;

--
-- Name: lurkers; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE lurkers (
    "user" bigint NOT NULL,
    post bigint NOT NULL,
    "time" timestamp(0) with time zone NOT NULL,
    CONSTRAINT lurkerstimecheck CHECK ((date_part('timezone'::text, "time") = 0::double precision))
);


ALTER TABLE public.lurkers OWNER TO test_db;

--
-- Name: pms; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE pms (
    "from" bigint NOT NULL,
    "to" bigint NOT NULL,
    "time" timestamp(0) with time zone NOT NULL,
    message text NOT NULL,
    read boolean NOT NULL,
    pmid bigint NOT NULL,
    CONSTRAINT pmstimecheck CHECK ((date_part('timezone'::text, "time") = 0::double precision))
);


ALTER TABLE public.pms OWNER TO test_db;

--
-- Name: pms_pmid_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE pms_pmid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.pms_pmid_seq OWNER TO test_db;

--
-- Name: pms_pmid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE pms_pmid_seq OWNED BY pms.pmid;


--
-- Name: posts; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE posts (
    hpid bigint NOT NULL,
    "from" bigint NOT NULL,
    "to" bigint NOT NULL,
    pid bigint NOT NULL,
    message text NOT NULL,
    notify boolean DEFAULT false NOT NULL,
    "time" timestamp(0) with time zone NOT NULL,
    CONSTRAINT poststimecheck CHECK ((date_part('timezone'::text, "time") = 0::double precision))
);


ALTER TABLE public.posts OWNER TO test_db;

--
-- Name: posts_hpid_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE posts_hpid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.posts_hpid_seq OWNER TO test_db;

--
-- Name: posts_hpid_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE posts_hpid_seq OWNED BY posts.hpid;


--
-- Name: posts_no_notify; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE posts_no_notify (
    "user" bigint NOT NULL,
    hpid bigint NOT NULL,
    "time" timestamp(0) with time zone NOT NULL,
    CONSTRAINT postsnonotifytimecheck CHECK ((date_part('timezone'::text, "time") = 0::double precision))
);


ALTER TABLE public.posts_no_notify OWNER TO test_db;

--
-- Name: profiles; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE profiles (
    counter bigint NOT NULL,
    remote_addr inet,
    http_user_agent text NOT NULL,
    website character varying(350) DEFAULT ''::character varying NOT NULL,
    quotes text DEFAULT ''::text NOT NULL,
    biography text DEFAULT ''::text NOT NULL,
    interests text DEFAULT ''::text NOT NULL,
    github character varying(350) DEFAULT ''::character varying NOT NULL,
    skype character varying(350) DEFAULT ''::character varying NOT NULL,
    jabber character varying(350) DEFAULT ''::character varying NOT NULL,
    yahoo character varying(350) DEFAULT ''::character varying NOT NULL,
    userscript character varying(128) DEFAULT ''::character varying NOT NULL,
    template smallint DEFAULT 0 NOT NULL,
    mobile_template smallint DEFAULT 1 NOT NULL,
    dateformat character varying(25) DEFAULT 'd/m/Y, H:i'::character varying NOT NULL,
    facebook character varying(350) DEFAULT ''::character varying NOT NULL,
    twitter character varying(350) DEFAULT ''::character varying NOT NULL,
    steam character varying(350) DEFAULT ''::character varying NOT NULL,
    push boolean DEFAULT false NOT NULL,
    pushregtime timestamp(0) with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.profiles OWNER TO test_db;

--
-- Name: profiles_counter_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE profiles_counter_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.profiles_counter_seq OWNER TO test_db;

--
-- Name: profiles_counter_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE profiles_counter_seq OWNED BY profiles.counter;


--
-- Name: thumbs; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE thumbs (
    hpid bigint NOT NULL,
    "user" bigint NOT NULL,
    vote smallint NOT NULL,
    CONSTRAINT chkvote CHECK ((vote = ANY (ARRAY[(-1), 0, 1])))
);


ALTER TABLE public.thumbs OWNER TO test_db;

--
-- Name: users; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE users (
    counter bigint NOT NULL,
    last timestamp(0) with time zone DEFAULT now() NOT NULL,
    notify_story json,
    private boolean DEFAULT false NOT NULL,
    lang character varying(2) DEFAULT 'en'::character varying NOT NULL,
    username character varying(90) NOT NULL,
    password character varying(40) NOT NULL,
    name character varying(60) NOT NULL,
    surname character varying(60) NOT NULL,
    email character varying(350) NOT NULL,
    gender boolean NOT NULL,
    birth_date date NOT NULL,
    board_lang character varying(2) DEFAULT 'en'::character varying NOT NULL,
    timezone character varying(35) DEFAULT 'UTC'::character varying NOT NULL,
    viewonline boolean DEFAULT true NOT NULL,
    CONSTRAINT userslastcheck CHECK ((date_part('timezone'::text, last) = 0::double precision))
);


ALTER TABLE public.users OWNER TO test_db;

--
-- Name: users_counter_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE users_counter_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.users_counter_seq OWNER TO test_db;

--
-- Name: users_counter_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE users_counter_seq OWNED BY users.counter;


--
-- Name: whitelist; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE whitelist (
    "from" bigint NOT NULL,
    "to" bigint NOT NULL
);


ALTER TABLE public.whitelist OWNER TO test_db;

--
-- Name: hcid; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY comments ALTER COLUMN hcid SET DEFAULT nextval('comments_hcid_seq'::regclass);


--
-- Name: counter; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups ALTER COLUMN counter SET DEFAULT nextval('groups_counter_seq'::regclass);


--
-- Name: hcid; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_comments ALTER COLUMN hcid SET DEFAULT nextval('groups_comments_hcid_seq'::regclass);


--
-- Name: hpid; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_posts ALTER COLUMN hpid SET DEFAULT nextval('groups_posts_hpid_seq'::regclass);


--
-- Name: pmid; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY pms ALTER COLUMN pmid SET DEFAULT nextval('pms_pmid_seq'::regclass);


--
-- Name: hpid; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY posts ALTER COLUMN hpid SET DEFAULT nextval('posts_hpid_seq'::regclass);


--
-- Name: counter; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY profiles ALTER COLUMN counter SET DEFAULT nextval('profiles_counter_seq'::regclass);


--
-- Name: counter; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY users ALTER COLUMN counter SET DEFAULT nextval('users_counter_seq'::regclass);


--
-- Data for Name: ban; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY ban ("user", motivation) FROM stdin;
\.


--
-- Data for Name: blacklist; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY blacklist ("from", "to", motivation) FROM stdin;
4	2	[big]Dirty peasant.[/big]
1	5	You&#039;re an asshole :&gt;
\.


--
-- Data for Name: bookmarks; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY bookmarks ("from", hpid, "time") FROM stdin;
1	6	2014-04-26 15:10:12+00
3	13	2014-04-26 15:34:06+00
6	35	2014-04-26 16:08:29+00
1	38	2014-04-26 16:14:23+00
12	47	2014-04-26 16:36:42+00
12	44	2014-04-26 16:36:44+00
12	48	2014-04-26 16:36:45+00
6	54	2014-04-26 16:44:38+00
3	58	2014-04-26 18:16:35+00
\.


--
-- Data for Name: closed_profiles; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY closed_profiles (counter) FROM stdin;
7
6
\.


--
-- Data for Name: comment_thumbs; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY comment_thumbs (hcid, "user", vote) FROM stdin;
4	1	1
17	3	1
32	3	0
109	12	1
108	12	1
105	12	1
103	12	1
102	12	1
159	3	1
156	3	1
156	1	1
\.


--
-- Data for Name: comments; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY comments ("from", "to", hpid, message, "time", hcid) FROM stdin;
1	1	4	[img]https://fbcdn-sphotos-f-a.akamaihd.net/hphotos-ak-frc1/t1.0-9/q71/s720x720/10295706_754761757878221_576570612184366073_n.jpg[/img] SALVO HELP	2014-04-26 15:04:55+00	1
2	1	6	Non pi&ugrave;	2014-04-26 15:11:21+00	2
1	1	6	Ciao Peppa :&gt; benvenuta su NERDZ! Come hai trovato questo sito?	2014-04-26 15:12:26+00	3
1	2	8	HOLA PORTUGAL[hr][commentquote=[user]admin[/user]]HOLA PORTUGAL[/commentquote]	2014-04-26 15:13:28+00	4
2	1	6	[commentquote=[user]admin[/user]]Ciao Peppa :&gt; benvenuta su NERDZ! Come hai trovato questo sito?[/commentquote]Culo	2014-04-26 15:13:43+00	5
1	1	6	nn 6 simpa	2014-04-26 15:15:13+00	6
2	1	6	:&lt; ma sono sincera e pura. Anche se dal nome non si direbbe.	2014-04-26 15:16:48+00	7
1	1	6	E dal fatto che per disegnarti come base devo fare un pene? Come giustifichi questo?	2014-04-26 15:17:38+00	8
2	1	6	[commentquote=[user]admin[/user]]E dal fatto che per disegnarti come base devo fare un pene? Come giustifichi questo?[/commentquote]Queste sono insinuazioni prive di fondamento. Infatti se faccio un disegno di me... Oh wait.	2014-04-26 15:19:56+00	9
2	1	10	Meglio di Patrick c&#039;&egrave; solo Xeno	2014-04-26 15:26:27+00	10
1	1	10	Meglio di Xeno c&#039;&egrave; solo *	2014-04-26 15:26:46+00	11
3	3	11	I&#039;m doing some tests.\n\nI want to see mcilloni, my dear friend.	2014-04-26 15:27:19+00	12
2	1	10	Meglio di * c&#039;&egrave; solo Peppa. ALL HAIL PEPPAPIG!	2014-04-26 15:28:05+00	13
1	4	12	OMG GABEN, I LOVE YOU	2014-04-26 15:28:08+00	14
1	1	10	VAI VIA XENO	2014-04-26 15:28:24+00	15
2	1	10	[commentquote=[user]admin[/user]]VAI VIA XENO[/commentquote][commentquote=[user]admin[/user]]VAI VIA XENO[/commentquote][commentquote=[user]admin[/user]]VAI VIA XENO[/commentquote][commentquote=[user]admin[/user]]VAI VIA XENO[/commentquote][commentquote=[user]admin[/user]]VAI VIA XENO[/commentquote][commentquote=[user]admin[/user]]VAI VIA XENO[/commentquote][commentquote=[user]admin[/user]]VAI VIA XENO[/commentquote][commentquote=[user]admin[/user]]VAI VIA XENO[/commentquote][commentquote=[user]admin[/user]]VAI VIA XENO[/commentquote][commentquote=[user]admin[/user]]VAI VIA XENO[/commentquote]	2014-04-26 15:28:45+00	16
1	4	15	You&#039;re not funny :&lt;	2014-04-26 15:28:46+00	17
2	3	13	VAI VIA XENO!	2014-04-26 15:29:04+00	18
3	3	13	Who&#039;s Xeno?	2014-04-26 15:29:21+00	19
4	4	15	But it was worth the weight, wasn&#039;t it?	2014-04-26 15:29:23+00	20
2	4	12	Omg, gaben gimme steam&#039;s games plz	2014-04-26 15:29:36+00	21
2	3	13	YOU ARE XENO! &gt;VAI VIA	2014-04-26 15:30:08+00	22
4	4	12	Unfortunately that is not allowed, and your account has been permanently banned.	2014-04-26 15:30:40+00	23
1	4	15	It wasn&#039;t. Your sentence just killed me.	2014-04-26 15:30:48+00	24
1	4	12	[img]http://i.imgur.com/4VkOPTx.gif[/img] &lt;3&lt;3&lt;3	2014-04-26 15:31:24+00	25
4	4	15	I&#039;m sorry. Here, have some free Team Fortress 2 hats.	2014-04-26 15:31:30+00	26
4	4	12	[big]Glorious Gaben&#039;s beard[/big]	2014-04-26 15:31:56+00	27
4	4	16	[commentquote=[user]Gaben[/user]][big]Glorious Gaben&#039;s beard[/big][/commentquote]	2014-04-26 15:32:33+00	29
3	3	13	Please PeppaPig, you&#039;re not funny.\nGo away...	2014-04-26 15:32:41+00	30
1	3	13	There&#039;s a non-written rule on this website.\nIf someone ask &quot;who&#039;s xeno&quot;, well, this one is xeno.	2014-04-26 15:32:50+00	31
3	3	13	[commentquote=[user]admin[/user]]There&#039;s a non-written rule on this website.\nIf someone ask &quot;who&#039;s xeno&quot;, well, this one is xeno.[/commentquote]\nI don&#039;t like it.[hr]It&#039;s quite stupid that I&#039;m able to put a &quot;finger up&quot; or a &quot;finger down&quot; to my posts...	2014-04-26 15:33:56+00	32
1	3	13	Well, after a complex and long reflection about that. We decided that is not stupid. Even bit boards like reddit do this[hr]*big	2014-04-26 15:34:55+00	33
2	1	18	PEPPE CRILLIN E&#039; IL MIO DIO. IN PORTOGALLO E&#039; VENERATO DA GRANDI E PICCINI, SIAMO TUTTI GRILLINI.	2014-04-26 15:36:31+00	34
1	1	18	GRILINI BELI NON SAPEVO KE PEPPA FOSSE UNA PORTOGHESE CHE PARLA ITALIANO HOLA	2014-04-26 15:37:13+00	35
4	1	19	[img]https://scontent-a.xx.fbcdn.net/hphotos-prn1/t1/1526365_10153748828130093_531967148_n.jpg[/img]	2014-04-26 15:37:37+00	36
1	1	19	AWESOME DESKTOP. WHAT&#039;S THAT PLUG IN?	2014-04-26 15:38:13+00	37
4	1	19	Enhanced sexy look 2.0, released only for the Gabecube.	2014-04-26 15:39:18+00	38
1	1	19	DO WANT	2014-04-26 15:39:51+00	39
1	4	23	You&#039;re on the top of the world. Women loves you and even men do that.\nYou&#039;re the swaggest person on this stupid planet.\nTHANK YOU GABEN!\n\nHL3?	2014-04-26 15:43:28+00	40
1	2	14	pls, get a life	2014-04-26 15:43:53+00	41
4	1	22	I don&#039;t understand what did you say, but I am releasing the secret pictures of me and you, taken by an anonymous user yesterday night.\n[img]http://i.imgur.com/dbyH8Ke.jpg[/img]	2014-04-26 15:43:57+00	42
4	4	23	Please check NERDZilla.	2014-04-26 15:44:13+00	43
1	4	23	OH MY LORD	2014-04-26 15:44:44+00	44
2	1	19	[img]https://www.kirsle.net/creativity/articles/doswin31.png[/img]	2014-04-26 15:45:24+00	45
1	1	22	You confirmed HL3. My life has a sense now. I&#039;m proud if this pic.	2014-04-26 15:45:37+00	46
4	1	19	Blacklisting PeppaFag.	2014-04-26 15:45:46+00	47
1	1	19	PLS THIS IS VIRTULAL BOX PEPPA	2014-04-26 15:45:56+00	48
1	4	26	:o PLS NO	2014-04-26 15:48:02+00	49
5	5	27	Ask your sister	2014-04-26 15:49:24+00	50
1	5	27	This is not funny. Blacklisted :&gt;	2014-04-26 15:50:47+00	51
6	6	29	Qualcosa a met&agrave; fra i due	2014-04-26 15:52:07+00	52
1	6	29	ah scusa sei taliano, sar&agrave; il vero doch oppure no? dilemma del giorno[hr]NO PLS NON MI MENTIRE	2014-04-26 15:52:30+00	53
6	6	29	Dovrai fidarti di me, mi dispiace	2014-04-26 15:53:52+00	54
1	6	29	Non mi fido di uno che dice di essere un 88 pur essendo un 95. TU TROLLI.\nE si, mettere un numero alla fine del nickname indica l&#039;anno di nascita. LRN2MSN	2014-04-26 15:54:54+00	55
15	13	54	ghouloso	2014-04-26 18:08:59+00	155
1	6	31	Hai ragionissimo, indica il problema pls che debbo fixare	2014-04-26 15:55:19+00	56
6	6	31	Beh, ho cambiato nick in &quot;Doch&quot; e mi ha cambiato solo il link del profilo lol	2014-04-26 15:55:53+00	57
2	1	19	[commentquote=[user]admin[/user]]PLS THIS IS VIRTULAL BOX PEPPA[/commentquote]OH NOES, M&#039;HAI BECCATA D: Sto emulando win 3.1 su win 3.1 cuz im SWEG\n[yt]https://www.youtube.com/watch?v=KTJVlJ25S8c[/yt]	2014-04-26 15:55:56+00	58
2	6	29	VAI VIA XENO	2014-04-26 15:56:40+00	59
1	6	31	nosp&egrave;, manca la news e quello &egrave; l&#039;unico problema che mi viene in mente	2014-04-26 15:56:50+00	60
6	6	31	[commentquote=[user]admin[/user]]nosp&egrave;, manca la news e quello &egrave; l&#039;unico problema che mi viene in mente[/commentquote]^\nE magari che non cambia l&#039;utente che scrive i post ed i commenti? asd[hr]il link del mio profilo &egrave; [url]http://datcanada.dyndns.org/Doch.[/url]	2014-04-26 15:57:48+00	61
2	1	24	&gt;[FR] Je suis un fille fillo\nMI STAI INSULTANDO? EH? CE L&#039;HAI CON ME? EH? TI SPACCIO LA FACCIA!	2014-04-26 15:58:28+00	62
6	6	29	[commentquote=[user]admin[/user]]Non mi fido di uno che dice di essere un 88 pur essendo un 95. TU TROLLI.\nE si, mettere un numero alla fine del nickname indica l&#039;anno di nascita. LRN2MSN[/commentquote]Cos&igrave; mi ferisci :([hr][commentquote=[user]PeppaPig[/user]]VAI VIA XENO[/commentquote]Che bello, ora so cosa provano i nuovi utenti quando si sentono dire di essere xeno asd	2014-04-26 16:00:01+00	63
6	6	34	Nope, preferisco gli Ananas	2014-04-26 16:03:23+00	64
1	6	31	E di fatti io quello vedo o.o	2014-04-26 16:03:27+00	65
1	1	24	PLS XENO	2014-04-26 16:03:36+00	66
6	6	31	[commentquote=[user]admin[/user]]E di fatti io quello vedo o.o[/commentquote]Io no per&ograve; asd	2014-04-26 16:03:47+00	67
1	6	34	HAI UNA COSA IN COMUNE CON PATRIK, STA NESCENDO L&#039;AMORE	2014-04-26 16:03:54+00	68
2	6	34	[commentquote=[user]Doch[/user]]Nope, preferisco gli Ananas[/commentquote]Nosp&egrave;, cosa usi per mangiare? :o	2014-04-26 16:03:58+00	69
1	6	31	Perch&eacute; non ha aggiornato la variabile di sessione che contiene il valore del nick, dato che ha fallito l&#039;inserimento del post dell&#039;utente news :&lt; in sostnaza se ti slogghi e rientri (oppure se cambio ancora nick) dovrebbe andre	2014-04-26 16:04:46+00	70
6	6	34	[commentquote=[user]PeppaPig[/user]][commentquote=[user]Doch[/user]]Nope, preferisco gli Ananas[/commentquote]Nosp&egrave;, cosa usi per mangiare? :o[/commentquote]Di solito uso le spatole, amo le spatole	2014-04-26 16:04:48+00	71
2	1	24	E poi non ho capito questo razzismo nei confronti dei portoghesi. Metti la traduzione in portoghese pls	2014-04-26 16:04:56+00	72
1	1	24	HAI RAGIONE[hr]fatto	2014-04-26 16:05:29+00	73
6	6	31	[commentquote=[user]admin[/user]]Perch&eacute; non ha aggiornato la variabile di sessione che contiene il valore del nick, dato che ha fallito l&#039;inserimento del post dell&#039;utente news :&lt; in sostnaza se ti slogghi e rientri (oppure se cambio ancora nick) dovrebbe andre[/commentquote]K, ora va, anche se ho dovuto farmi reinviare la password perch&eacute; quella con cui mi sono iscritto non andava lol	2014-04-26 16:07:34+00	74
2	1	24	Ma non era qualcosa tipo:\n[PT]Guardao lo meo profilao, porqu&egrave; ho aggiornao i quotao i li intessao :{D	2014-04-26 16:07:46+00	75
1	6	31	Pensa te che funziona perfino questo :O	2014-04-26 16:08:32+00	76
1	1	24	No	2014-04-26 16:08:42+00	77
2	1	35	[url]http://www.pornhub.com/[/url]\nJust better	2014-04-26 16:09:07+00	78
1	2	33	faq.php#q19	2014-04-26 16:09:19+00	79
2	1	24	ok :&lt;	2014-04-26 16:09:31+00	80
1	1	35	NO LANGUAGE SKILLS REQUIRED	2014-04-26 16:09:38+00	81
2	2	33	Ma solo con gravatar? Non posso caricare un&#039;img random? :&lt;	2014-04-26 16:11:46+00	82
1	2	33	No, gravatar &egrave; l&#039;unico modo supportato	2014-04-26 16:12:29+00	83
1	2	33	pls niente madonne che sta roba deve essere pubblica e usata da un tot di persone	2014-04-26 16:13:20+00	85
1	8	39	9/10 &egrave; xeno[hr]Cosa ne pensi di supernatural?	2014-04-26 16:14:50+00	86
2	2	38	parla come magni AO!	2014-04-26 16:15:40+00	87
8	8	39	Anch&#039;io sono un porco, dobbiamo convincerci\n[commentquote=[user]admin[/user]]9/10 &egrave; xeno[hr]Cosa ne pensi di supernatural?[/commentquote]E&#039; una serie stupenda, amo la storia d&#039;amore fra Pamela e Jerry, poi quando Timmy muore mi sono quasi messo a piangere	2014-04-26 16:16:50+00	88
9	8	39	&lt;?php die(&#039;HACKED!!!&#039;); ?&gt;	2014-04-26 16:19:13+00	89
9	2	38	&lt;?php die(&#039;HACKED!!!&#039;); ?&gt;	2014-04-26 16:19:20+00	90
2	10	42	THE WINTER IS CUMMING [cit]	2014-04-26 16:19:58+00	91
10	10	42	:VVVVVVV[hr][url=http://datcanada.dyndns.org][img]https://fbcdn-sphotos-a-a.akamaihd.net/hphotos-ak-ash3/t1.0-9/1491727_689713044420348_2018650436150533672_n.jpg[/img][/url]	2014-04-26 16:21:04+00	92
6	10	42	[commentquote=[user]winter[/user]]:VVVVVVV[hr][url=http://datcanada.dyndns.org][img]https://fbcdn-sphotos-a-a.akamaihd.net/hphotos-ak-ash3/t1.0-9/1491727_689713044420348_2018650436150533672_n.jpg[/img][/url][/commentquote]NO! PLS!	2014-04-26 16:21:04+00	93
10	10	42	awwwwwww\ni didn&#039;t know you were here ;______________;	2014-04-26 16:21:23+00	94
11	11	44	Ciao mamma di xeno, perch&egrave; non ti registri anche nel nerdz vero?	2014-04-26 16:26:03+00	95
2	11	44	Perch&egrave; ho sempre tanto da &quot;fare&quot;. Comunque sappi che mio figlio non c&#039;&egrave; mai in casa, perch&eacute; quando entra gli dico sempre &quot;VAI VIA XENO&quot; e lui esce depresso e va dai suoi amici... oh wait, lui non ha amici :o	2014-04-26 16:28:38+00	96
11	11	44	pls poi ritorna a casa con un altro nome\n\nMA L&#039;UA NON MENTE MAI, COME LE IMPRONTI DIGITALI	2014-04-26 16:29:24+00	97
2	11	44	Si, infatti quando torna lo riconosco dal tatuaggio sulla chiappa con scritto Linux 32bit	2014-04-26 16:30:31+00	98
9	9	45	AHAHAHHAHAHAHAHAHAHAHHAHAHAHA QUESTO SITO &Egrave; INSICURO\nPERMETTE DI INSERIRE CODICE JAVASCRIPT ARBITRARIO DAL CAMPO USERSCRIPT	2014-04-26 16:35:13+00	99
2	9	45	[commentquote=[user]&lt;script&gt;alert(1)[/user]]AHAHAHHAHAHAHAHAHAHAHHAHAHAHA QUESTO SITO &Egrave; INSICURO\nPERMETTE DI INSERIRE CODICE JAVASCRIPT ARBITRARIO DAL CAMPO USERSCRIPT[/commentquote]Oh noes, pls explain me how :o	2014-04-26 16:35:52+00	100
3	15	61	TOO FAKE	2014-04-26 18:16:15+00	158
9	9	45	OVVIO, BASTA PARTIRE DAL JAVASCRIPT DEL CAMPO USERSCRIPT CHE SOLO IO POSSO ESEGUIRE E ACCEDERE AL DATABASE, FACILE NO?	2014-04-26 16:36:37+00	101
9	12	49	ROBERTOF	2014-04-26 16:36:44+00	102
13	12	49	RETTILIANI!	2014-04-26 16:37:21+00	103
2	9	45	[commentquote=[user]&lt;script&gt;alert(1)[/user]]OVVIO, BASTA PARTIRE DAL JAVASCRIPT DEL CAMPO USERSCRIPT CHE SOLO IO POSSO ESEGUIRE E ACCEDERE AL DATABASE, FACILE NO?[/commentquote]No wait, mi stai dicendo che se inserisco codice js nel campo userscript posso fare cose da haxor? :o	2014-04-26 16:37:39+00	104
2	12	49	VEGANI, VEGANI EVERYWHERE	2014-04-26 16:38:16+00	105
9	9	45	SI PROVA, IO HO QUASI IL DUMP DEL DB[hr]manca ancora pcood.....	2014-04-26 16:38:25+00	106
2	13	50	Basta chiederlo a Dod&ograve;	2014-04-26 16:38:37+00	107
13	12	49	SKY CINEMA	2014-04-26 16:38:43+00	108
9	12	49	Qualcuno ha detto dump del database?	2014-04-26 16:38:46+00	109
2	9	45	[commentquote=[user]&lt;script&gt;alert(1)[/user]]SI PROVA, IO HO QUASI IL DUMP DEL DB[hr]manca ancora pcood.....[/commentquote]manca solo porcodio? MA E&#039; SEMPLICE QUELLO!	2014-04-26 16:39:05+00	110
11	11	51	sheeeit	2014-04-26 16:39:07+00	111
2	12	52	VAI VIA CRILIN\n[img]http://cdn.freebievectors.com/illustrations/7/d/dragon-ball-krillin/preview.jpg[/img]	2014-04-26 16:41:39+00	112
2	12	49	Qualcuno ha detto LA CASTA?[hr][commentquote=[user]&lt;script&gt;alert(1)[/user]]ROBERTOF[/commentquote]GABEN? Dove?	2014-04-26 16:44:00+00	113
2	2	55	Salve albero abitato da un uccello di pezza	2014-04-26 16:46:32+00	114
13	2	55	Quell&#039;uccello ormai &egrave; parte di me, ce l&#039;ho dentro da cos&igrave; tanto tempo che non mi ricordo nemmeno quando venne per la prima volta	2014-04-26 16:48:42+00	115
2	2	55	[commentquote=[user]Albero Azzurro[/user]]Quell&#039;uccello ormai &egrave; parte di me, ce l&#039;ho dentro da cos&igrave; tanto tempo che non mi ricordo nemmeno quando venne per la prima volta[/commentquote]Mi attizzi assai quando dici queste cose, lo sai?	2014-04-26 16:49:24+00	116
13	2	55	[commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]]Quell&#039;uccello ormai &egrave; parte di me, ce l&#039;ho dentro da cos&igrave; tanto tempo che non mi ricordo nemmeno quando venne per la prima volta[/commentquote]Mi attizzi assai quando dici queste cose, lo sai?[/commentquote]Sono penetrato nella tua anima?	2014-04-26 16:50:22+00	118
1	8	39	pls	2014-04-26 16:51:07+00	119
1	1	47	Sono commosso :&#039;)	2014-04-26 16:51:17+00	120
2	2	55	[commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]]Quell&#039;uccello ormai &egrave; parte di me, ce l&#039;ho dentro da cos&igrave; tanto tempo che non mi ricordo nemmeno quando venne per la prima volta[/commentquote]Mi attizzi assai quando dici queste cose, lo sai?[/commentquote]Sono penetrato nella tua anima?[/commentquote]Sai io sono aperta a tutto, mi piacciono uomini, donne, xenomorfi, gufi e anche gli alberi non li disprezzo ;) :*	2014-04-26 16:51:51+00	121
1	13	54	Davvero buono.	2014-04-26 16:51:59+00	122
13	2	55	[commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]]Quell&#039;uccello ormai &egrave; parte di me, ce l&#039;ho dentro da cos&igrave; tanto tempo che non mi ricordo nemmeno quando venne per la prima volta[/commentquote]Mi attizzi assai quando dici queste cose, lo sai?[/commentquote]Sono penetrato nella tua anima?[/commentquote]Sai io sono aperta a tutto, mi piacciono uomini, donne, xenomorfi, gufi e anche gli alberi non li disprezzo ;) :*[/commentquote]La mia corteccia &egrave; molto dura, potrei farti male	2014-04-26 16:52:46+00	123
1	2	56	Tanto non lo leggono :&gt;	2014-04-26 16:52:56+00	124
2	2	55	[commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]]Quell&#039;uccello ormai &egrave; parte di me, ce l&#039;ho dentro da cos&igrave; tanto tempo che non mi ricordo nemmeno quando venne per la prima volta[/commentquote]Mi attizzi assai quando dici queste cose, lo sai?[/commentquote]Sono penetrato nella tua anima?[/commentquote]Sai io sono aperta a tutto, mi piacciono uomini, donne, xenomorfi, gufi e anche gli alberi non li disprezzo ;) :*[/commentquote]La mia corteccia &egrave; molto dura, potrei farti male[/commentquote]Non preoccuparti, usiamo la tua linfa come lubrificante ;*	2014-04-26 16:54:20+00	125
13	13	54	[commentquote=[user]admin[/user]]Davvero buono.[/commentquote]Vero? \nL&#039;hai provato aggiungendo della mortadella? Nemmeno ti immagini quant&#039;&egrave; buono	2014-04-26 16:55:41+00	126
2	2	56	[commentquote=[user]admin[/user]]Tanto non lo leggono :&gt;[/commentquote]Sono tutti fag	2014-04-26 16:56:56+00	127
13	2	55	[commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]]Quell&#039;uccello ormai &egrave; parte di me, ce l&#039;ho dentro da cos&igrave; tanto tempo che non mi ricordo nemmeno quando venne per la prima volta[/commentquote]Mi attizzi assai quando dici queste cose, lo sai?[/commentquote]Sono penetrato nella tua anima?[/commentquote]Sai io sono aperta a tutto, mi piacciono uomini, donne, xenomorfi, gufi e anche gli alberi non li disprezzo ;) :*[/commentquote]La mia corteccia &egrave; molto dura, potrei farti male[/commentquote]Non preoccuparti, usiamo la tua linfa come lubrificante ;*[/commentquote]Perfetto allora, ti penetrer&ograve; col mio lungo ramo ed entrer&ograve; dentro di te, che sarai cos&igrave; calda da poterci fare una brace :*\nTi aspetto qui, insieme all&#039;uccello	2014-04-26 16:58:23+00	128
2	14	59	Ho sempre saputo che ges&ugrave; e mcilloni non erano la stessa persona :v	2014-04-26 18:14:46+00	156
2	16	84	Principianti, io mi sono sgommato durante un rapporto sessuale[hr]sgommata*\nPS e stavamo facendo anal	2014-04-27 18:06:50+00	208
18	18	85	JOIN OUR KLUB\nWE EAT \nSWEET CHOCOLATE.[hr](era klan una volta ma ora &egrave; troppo nigga quella parola. Vado a lavarmi le dita)	2014-04-27 18:11:27+00	210
2	16	84	[commentquote=[user]PUNCHMYDICK[/user]]E tu eri il passivo?[hr]Dopo hai urlato &quot;QUESTA E&#039; LA SINDONE&quot;?[/commentquote]Sono PeppaPig aka Giuseppina Maiala aka sono female.\nRiguardo la questione dell&#039;urlo, mi sembra ovvio, non mi faccio mai scappare queste opportunit&agrave;.	2014-04-27 18:17:51+00	211
1	16	79	ღ Beppe ღ ღ Beppe ღ ღ Beppe ღ ღ Beppe ღ ღ Beppe ღ ღ Beppe ღ ღ Beppe ღ ღ Beppe ღ	2014-04-27 18:37:07+00	215
2	2	86	[commentquote=[user]admin[/user]]xeno[/commentquote]Oh pls, sono la madre, ma lo disprezzo pure io :(	2014-04-27 19:57:21+00	218
2	2	55	[commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]]Quell&#039;uccello ormai &egrave; parte di me, ce l&#039;ho dentro da cos&igrave; tanto tempo che non mi ricordo nemmeno quando venne per la prima volta[/commentquote]Mi attizzi assai quando dici queste cose, lo sai?[/commentquote]Sono penetrato nella tua anima?[/commentquote]Sai io sono aperta a tutto, mi piacciono uomini, donne, xenomorfi, gufi e anche gli alberi non li disprezzo ;) :*[/commentquote]La mia corteccia &egrave; molto dura, potrei farti male[/commentquote]Non preoccuparti, usiamo la tua linfa come lubrificante ;*[/commentquote]Perfetto allora, ti penetrer&ograve; col mio lungo ramo ed entrer&ograve; dentro di te, che sarai cos&igrave; calda da poterci fare una brace :*\nTi aspetto qui, insieme all&#039;uccello[/commentquote]Senti, facciamo domani che oggi devo passare dal gufo, si dice che lui stesso &egrave; tutto uccello...	2014-04-26 17:02:22+00	129
13	2	55	[commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]]Quell&#039;uccello ormai &egrave; parte di me, ce l&#039;ho dentro da cos&igrave; tanto tempo che non mi ricordo nemmeno quando venne per la prima volta[/commentquote]Mi attizzi assai quando dici queste cose, lo sai?[/commentquote]Sono penetrato nella tua anima?[/commentquote]Sai io sono aperta a tutto, mi piacciono uomini, donne, xenomorfi, gufi e anche gli alberi non li disprezzo ;) :*[/commentquote]La mia corteccia &egrave; molto dura, potrei farti male[/commentquote]Non preoccuparti, usiamo la tua linfa come lubrificante ;*[/commentquote]Perfetto allora, ti penetrer&ograve; col mio lungo ramo ed entrer&ograve; dentro di te, che sarai cos&igrave; calda da poterci fare una brace :*\nTi aspetto qui, insieme all&#039;uccello[/commentquote]Senti, facciamo domani che oggi devo passare dal gufo, si dice che lui stesso &egrave; tutto uccello...[/commentquote]Mi tradisci per un uccello pi&ugrave; grosso del mio?	2014-04-26 17:03:31+00	130
2	2	55	[commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]]Quell&#039;uccello ormai &egrave; parte di me, ce l&#039;ho dentro da cos&igrave; tanto tempo che non mi ricordo nemmeno quando venne per la prima volta[/commentquote]Mi attizzi assai quando dici queste cose, lo sai?[/commentquote]Sono penetrato nella tua anima?[/commentquote]Sai io sono aperta a tutto, mi piacciono uomini, donne, xenomorfi, gufi e anche gli alberi non li disprezzo ;) :*[/commentquote]La mia corteccia &egrave; molto dura, potrei farti male[/commentquote]Non preoccuparti, usiamo la tua linfa come lubrificante ;*[/commentquote]Perfetto allora, ti penetrer&ograve; col mio lungo ramo ed entrer&ograve; dentro di te, che sarai cos&igrave; calda da poterci fare una brace :*\nTi aspetto qui, insieme all&#039;uccello[/commentquote]Senti, facciamo domani che oggi devo passare dal gufo, si dice che lui stesso &egrave; tutto uccello...[/commentquote]Mi tradisci per un uccello pi&ugrave; grosso del mio?[/commentquote]Solo per oggi, domani sar&ograve; tutta tua &lt;3	2014-04-26 17:04:06+00	131
13	2	55	[commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]]Quell&#039;uccello ormai &egrave; parte di me, ce l&#039;ho dentro da cos&igrave; tanto tempo che non mi ricordo nemmeno quando venne per la prima volta[/commentquote]Mi attizzi assai quando dici queste cose, lo sai?[/commentquote]Sono penetrato nella tua anima?[/commentquote]Sai io sono aperta a tutto, mi piacciono uomini, donne, xenomorfi, gufi e anche gli alberi non li disprezzo ;) :*[/commentquote]La mia corteccia &egrave; molto dura, potrei farti male[/commentquote]Non preoccuparti, usiamo la tua linfa come lubrificante ;*[/commentquote]Perfetto allora, ti penetrer&ograve; col mio lungo ramo ed entrer&ograve; dentro di te, che sarai cos&igrave; calda da poterci fare una brace :*\nTi aspetto qui, insieme all&#039;uccello[/commentquote]Senti, facciamo domani che oggi devo passare dal gufo, si dice che lui stesso &egrave; tutto uccello...[/commentquote]Mi tradisci per un uccello pi&ugrave; grosso del mio?[/commentquote]Solo per oggi, domani sar&ograve; tutta tua &lt;3[/commentquote]Ho visto fin troppe fighe di legno ultimamente, ma probabilmente tu non sei una di queste &lt;3	2014-04-26 17:07:18+00	132
2	2	55	[commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]]Quell&#039;uccello ormai &egrave; parte di me, ce l&#039;ho dentro da cos&igrave; tanto tempo che non mi ricordo nemmeno quando venne per la prima volta[/commentquote]Mi attizzi assai quando dici queste cose, lo sai?[/commentquote]Sono penetrato nella tua anima?[/commentquote]Sai io sono aperta a tutto, mi piacciono uomini, donne, xenomorfi, gufi e anche gli alberi non li disprezzo ;) :*[/commentquote]La mia corteccia &egrave; molto dura, potrei farti male[/commentquote]Non preoccuparti, usiamo la tua linfa come lubrificante ;*[/commentquote]Perfetto allora, ti penetrer&ograve; col mio lungo ramo ed entrer&ograve; dentro di te, che sarai cos&igrave; calda da poterci fare una brace :*\nTi aspetto qui, insieme all&#039;uccello[/commentquote]Senti, facciamo domani che oggi devo passare dal gufo, si dice che lui stesso &egrave; tutto uccello...[/commentquote]Mi tradisci per un uccello pi&ugrave; grosso del mio?[/commentquote]Solo per oggi, domani sar&ograve; tutta tua &lt;3[/commentquote]Ho visto fin troppe fighe di legno ultimamente, ma probabilmente tu non sei una di queste &lt;3[/commentquote]Io frequento sempre i soliti porci, quindi mi serve qualcuno che ce l&#039;ha di legno massello :&gt;	2014-04-26 17:12:00+00	133
2	13	54	[commentquote=[user]Albero Azzurro[/user]][commentquote=[user]admin[/user]]Davvero buono.[/commentquote]Vero? \nL&#039;hai provato aggiungendo della mortadella? Nemmeno ti immagini quant&#039;&egrave; buono[/commentquote]ASSASSINO! LO SAPEVO CHE NON DOVEVO FIDARMI DI TE &ccedil;_&ccedil;	2014-04-26 17:12:57+00	134
3	3	60	Yes sure.\nYou&#039;re welcome	2014-04-26 18:14:58+00	157
16	16	84	E tu eri il passivo?[hr]Dopo hai urlato &quot;QUESTA E&#039; LA SINDONE&quot;?	2014-04-27 18:08:39+00	209
1	17	80	VAI VIA PER FAVORE	2014-04-27 18:36:55+00	214
10	10	89	uhm. e dire che &egrave; copiaincollato dalla lista dei bbcode.\n*le sigh*	2014-04-27 18:48:08+00	216
1	10	89	Se sei noobd	2014-04-27 18:49:57+00	217
13	2	55	[commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]]Quell&#039;uccello ormai &egrave; parte di me, ce l&#039;ho dentro da cos&igrave; tanto tempo che non mi ricordo nemmeno quando venne per la prima volta[/commentquote]Mi attizzi assai quando dici queste cose, lo sai?[/commentquote]Sono penetrato nella tua anima?[/commentquote]Sai io sono aperta a tutto, mi piacciono uomini, donne, xenomorfi, gufi e anche gli alberi non li disprezzo ;) :*[/commentquote]La mia corteccia &egrave; molto dura, potrei farti male[/commentquote]Non preoccuparti, usiamo la tua linfa come lubrificante ;*[/commentquote]Perfetto allora, ti penetrer&ograve; col mio lungo ramo ed entrer&ograve; dentro di te, che sarai cos&igrave; calda da poterci fare una brace :*\nTi aspetto qui, insieme all&#039;uccello[/commentquote]Senti, facciamo domani che oggi devo passare dal gufo, si dice che lui stesso &egrave; tutto uccello...[/commentquote]Mi tradisci per un uccello pi&ugrave; grosso del mio?[/commentquote]Solo per oggi, domani sar&ograve; tutta tua &lt;3[/commentquote]Ho visto fin troppe fighe di legno ultimamente, ma probabilmente tu non sei una di queste &lt;3[/commentquote]Io frequento sempre i soliti porci, quindi mi serve qualcuno che ce l&#039;ha di legno massello :&gt;[/commentquote]Il mio legno &egrave; parecchio duro, e la linfa al suo interno molto dolce, lo sentirai presto	2014-04-26 17:13:28+00	135
2	2	55	NO VAI VIA ASSASSINO! TI PIACE MANGIARE LA MORTADELLA COL RISOTTO ALLA MILANESE EH? VAI VIA! &ccedil;_&ccedil;	2014-04-26 17:14:50+00	136
13	13	54	[commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]admin[/user]]Davvero buono.[/commentquote]Vero? \nL&#039;hai provato aggiungendo della mortadella? Nemmeno ti immagini quant&#039;&egrave; buono[/commentquote]ASSASSINO! LO SAPEVO CHE NON DOVEVO FIDARMI DI TE &ccedil;_&ccedil;[/commentquote]Oh, no, mi hai frainteso, non era mortadella di maiale, ma di tofu, non mangerei mai uno della tua specie, sono vegano	2014-04-26 17:15:10+00	137
2	13	54	[commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]admin[/user]]Davvero buono.[/commentquote]Vero? \nL&#039;hai provato aggiungendo della mortadella? Nemmeno ti immagini quant&#039;&egrave; buono[/commentquote]ASSASSINO! LO SAPEVO CHE NON DOVEVO FIDARMI DI TE &ccedil;_&ccedil;[/commentquote]Oh, no, mi hai frainteso, non era mortadella di maiale, ma di tofu, non mangerei mai uno della tua specie, sono vegano[/commentquote]VAI VIA! UN VEGANO! VAI VIA!	2014-04-26 17:15:48+00	138
13	2	55	[commentquote=[user]PeppaPig[/user]]NO VAI VIA ASSASSINO! TI PIACE MANGIARE LA MORTADELLA COL RISOTTO ALLA MILANESE EH? VAI VIA! &ccedil;_&ccedil;[/commentquote]No, perfavore, hai capito male! &ccedil;_&ccedil;	2014-04-26 17:15:57+00	139
2	13	57	[commentquote=[user]PeppaPig[/user]]VEGANI, VEGANI EVERYWHERE[/commentquote][hr][commentquote=[user]PeppaPig[/user]]VEGANI, VEGANI EVERYWHERE[/commentquote][commentquote=[user]PeppaPig[/user]]VEGANI, VEGANI EVERYWHERE[/commentquote][commentquote=[user]PeppaPig[/user]]VEGANI, VEGANI EVERYWHERE[/commentquote][commentquote=[user]PeppaPig[/user]]VEGANI, VEGANI EVERYWHERE[/commentquote]	2014-04-26 17:16:31+00	140
2	2	55	[commentquote=[user]PeppaPig[/user]]VEGANI, VEGANI EVERYWHERE[/commentquote][hr][commentquote=[user]PeppaPig[/user]]VEGANI, VEGANI EVERYWHERE[/commentquote][commentquote=[user]PeppaPig[/user]]VEGANI, VEGANI EVERYWHERE[/commentquote][commentquote=[user]PeppaPig[/user]]VEGANI, VEGANI EVERYWHERE[/commentquote][commentquote=[user]PeppaPig[/user]]VEGANI, VEGANI EVERYWHERE[/commentquote][commentquote=[user]PeppaPig[/user]]VEGANI, VEGANI EVERYWHERE[/commentquote][commentquote=[user]PeppaPig[/user]]VEGANI, VEGANI EVERYWHERE[/commentquote]	2014-04-26 17:16:50+00	141
13	2	55	La nostra poteva essere una storia duratura, e tu la vuoi rovinare per un dettaglio del genere? &ccedil;_&ccedil;	2014-04-26 17:17:39+00	142
2	2	55	ORA NON HO PIU&#039; DUBBI, SEI XENO! D: [commentquote=[user]PeppaPig[/user]]VEGANI, VEGANI EVERYWHERE[/commentquote]	2014-04-26 17:18:54+00	143
13	2	55	[commentquote=[user]PeppaPig[/user]]ORA NON HO PIU&#039; DUBBI, SEI XENO! D: [commentquote=[user]PeppaPig[/user]]VEGANI, VEGANI EVERYWHERE[/commentquote][/commentquote]Mi hai deluso, io ti amavo!	2014-04-26 17:20:26+00	144
2	2	55	E poi duratura cosa? Tu volevi fare di me mortadella da gustare col tuo risotto! VAI VIA [commentquote=[user]PeppaPig[/user]]VEGANI, VEGANI EVERYWHERE[/commentquote]	2014-04-26 17:20:52+00	145
13	2	55	[commentquote=[user]PeppaPig[/user]]E poi duratura cosa? Tu volevi fare di me mortadella da gustare col tuo risotto! VAI VIA [commentquote=[user]PeppaPig[/user]]VEGANI, VEGANI EVERYWHERE[/commentquote][/commentquote]Non l&#039;avrei mai fatto, sarebbe stata una relazione secolare!	2014-04-26 17:22:20+00	146
2	2	55	Ma tu volevi solo il mio culatello!	2014-04-26 17:23:00+00	147
13	2	55	[commentquote=[user]PeppaPig[/user]]Ma tu volevi solo il mio culatello![/commentquote]No, volevo il tuo culo!	2014-04-26 17:24:04+00	148
2	2	55	[commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]]Ma tu volevi solo il mio culatello![/commentquote]No, volevo il tuo culo![/commentquote]Tu volevi appendermi come un salame!	2014-04-26 17:26:23+00	149
13	2	55	[commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]]Ma tu volevi solo il mio culatello![/commentquote]No, volevo il tuo culo![/commentquote]Tu volevi appendermi come un salame![/commentquote]Questo s&igrave;, ma non per mangiarti, &egrave; solo che amo il sado!	2014-04-26 17:29:12+00	150
2	2	55	[commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]]Ma tu volevi solo il mio culatello![/commentquote]No, volevo il tuo culo![/commentquote]Tu volevi appendermi come un salame![/commentquote]Questo s&igrave;, ma non per mangiarti, &egrave; solo che amo il sado![/commentquote]MA QUINDI LO AMMETTI! SEI UN ZOZZO LOSCO FAG-GIO!	2014-04-26 17:31:40+00	151
13	2	55	[commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]]Ma tu volevi solo il mio culatello![/commentquote]No, volevo il tuo culo![/commentquote]Tu volevi appendermi come un salame![/commentquote]Questo s&igrave;, ma non per mangiarti, &egrave; solo che amo il sado![/commentquote]MA QUINDI LO AMMETTI! SEI UN ZOZZO LOSCO FAG-GIO![/commentquote]Gi&agrave;, ormai mi sono radicato in questi vizi, e non ne vado fiero, quindi ti capisco se non vuoi pi&ugrave; avere a che fare con me &ccedil;_&ccedil;	2014-04-26 17:40:44+00	152
2	7	46	Oh, un ananas	2014-04-26 17:44:19+00	153
14	1	19	admin, che os e che wm usi?	2014-04-26 17:54:24+00	154
3	14	59	[commentquote=[user]PeppaPig[/user]]Ho sempre saputo che ges&ugrave; e mcilloni non erano la stessa persona :v[/commentquote][commentquote=[user]PeppaPig[/user]]Ho sempre saputo che ges&ugrave; e mcilloni non erano la stessa persona :v[/commentquote][commentquote=[user]PeppaPig[/user]]Ho sempre saputo che ges&ugrave; e mcilloni non erano la stessa persona :v[/commentquote][commentquote=[user]PeppaPig[/user]]Ho sempre saputo che ges&ugrave; e mcilloni non erano la stessa persona :v[/commentquote][commentquote=[user]PeppaPig[/user]]Ho sempre saputo che ges&ugrave; e mcilloni non erano la stessa persona :v[/commentquote][commentquote=[user]PeppaPig[/user]]Ho sempre saputo che ges&ugrave; e mcilloni non erano la stessa persona :v[/commentquote][commentquote=[user]PeppaPig[/user]]Ho sempre saputo che ges&ugrave; e mcilloni non erano la stessa persona :v[/commentquote][commentquote=[user]PeppaPig[/user]]Ho sempre saputo che ges&ugrave; e mcilloni non erano la stessa persona :v[/commentquote]	2014-04-26 18:16:28+00	159
2	15	61	[commentquote=[user]PeppaPig[/user]]Ho sempre saputo che ges&ugrave; e mcilloni non erano la stessa persona :v[/commentquote]	2014-04-26 18:17:34+00	160
10	12	53	LOLMYSQL\nFAG PLS	2014-04-26 18:35:28+00	161
2	1	64	PLS questa s&igrave; che &egrave; ora tarda &ugrave;.&ugrave;	2014-04-27 02:02:09+00	162
9	1	64	pls	2014-04-27 08:52:12+00	163
15	15	61	u fagu	2014-04-27 10:53:28+00	164
15	3	60	yay.	2014-04-27 10:53:37+00	165
1	2	63	No u ;&gt;	2014-04-27 12:48:47+00	166
1	1	19	fag	2014-04-27 12:50:14+00	167
2	2	63	[commentquote=[user]admin[/user]]No u ;&gt;[/commentquote]fap u :&lt;	2014-04-27 14:44:19+00	168
2	15	67	You are welcome :3	2014-04-27 14:48:23+00	169
2	2	68	Vade retro, demonio! &dagger;\nSei impossessato! &dagger;	2014-04-27 17:19:45+00	170
1	2	68	ESPANA OL&Egrave;[hr][code=code][code=code][code=code]\n[/code][/code][/code]	2014-04-27 17:29:44+00	171
1	1	70	Ciao mestesso	2014-04-27 17:31:47+00	172
1	3	60	:&#039;(	2014-04-27 17:32:03+00	173
2	2	68	[commentquote=[user]admin[/user]]ESPANA OL&Egrave;[hr][code=code][code=code][code=code]\n[/code][/code][/code][/commentquote]BUGS, BUGS EVERYWHERE	2014-04-27 17:35:34+00	174
2	16	77	mmm	2014-04-27 17:43:34+00	175
16	16	78	Ciao porca della situazione! Quindi scrivi cose zozze totalmente random?	2014-04-27 17:44:35+00	176
16	16	77	gnamgnam	2014-04-27 17:44:55+00	177
2	16	78	No, le cose zozze le faccio anche :*	2014-04-27 17:45:50+00	178
16	16	78	Yeah :&gt;	2014-04-27 17:46:16+00	179
17	14	59	[commentquote=[user]admin[/user]][img]https://fbcdn-sphotos-f-a.akamaihd.net/hphotos-ak-frc1/t1.0-9/q71/s720x720/10295706_754761757878221_576570612184366073_n.jpg[/img] SALVO HELP[/commentquote]	2014-04-27 17:47:29+00	180
2	16	81	MD discount?	2014-04-27 17:48:12+00	181
16	16	82	CIAO ADMIN	2014-04-27 17:52:35+00	182
18	16	81	QUEL DI&#039; SQUARCIAI UNA PATATA\nTANTO FUI FATTO COME UN PIRATA\nE L&#039;MD NEL MIO SANGUE GIACE.	2014-04-27 17:53:06+00	183
1	16	82	NON SARAI MAI AI MIEI LIVELLI, IO SONO ADMIN, INCHINATI	2014-04-27 17:53:29+00	184
18	15	67	AND SO \nGO ENDED WITH\nBUTT OVERFLOW.	2014-04-27 17:54:42+00	185
2	16	82	[commentquote=[user]admin[/user]]NON SARAI MAI AI MIEI LIVELLI, IO SONO ADMIN, INCHINATI[/commentquote]bitch pls	2014-04-27 17:54:43+00	186
18	1	66	ACHAB IS COMING\nAND WITH HIS PENIS\nYOUR ASS HUNTING.	2014-04-27 17:56:31+00	188
16	16	82	[commentquote=[user]admin[/user]]NON SARAI MAI AI MIEI LIVELLI, IO SONO ADMIN, INCHINATI[/commentquote]\nPOTREI CAMBIARE NICK IN \nPUNCHMYADMIN	2014-04-27 17:56:32+00	189
2	1	66	MA MA MA MI SOMIGLIA!	2014-04-27 17:56:53+00	190
2	16	82	[commentquote=[user]PUNCHMYDICK[/user]][commentquote=[user]admin[/user]]NON SARAI MAI AI MIEI LIVELLI, IO SONO ADMIN, INCHINATI[/commentquote]\nPOTREI CAMBIARE NICK IN \nPUNCHMYADMIN[/commentquote]bitch pls	2014-04-27 17:57:18+00	191
16	16	82	[commentquote=[user]PeppaPig[/user]][commentquote=[user]PUNCHMYDICK[/user]][commentquote=[user]admin[/user]]NON SARAI MAI AI MIEI LIVELLI, IO SONO ADMIN, INCHINATI[/commentquote]\nPOTREI CAMBIARE NICK IN \nPUNCHMYADMIN[/commentquote]bitch pls[/commentquote]\nPUNCHPEPPAPIG	2014-04-27 17:57:42+00	192
2	16	81	[commentquote=[user]kkklub[/user]]QUEL DI&#039; SQUARCIAI UNA PATATA\nTANTO FUI FATTO COME UN PIRATA\nE L&#039;MD NEL MIO SANGUE GIACE.[/commentquote][commentquote=[user]PeppaPig[/user]]MD discount?[/commentquote][hr][img]http://upload.wikimedia.org/wikipedia/it/c/ce/Md_discount.jpg[/img]	2014-04-27 17:58:20+00	187
2	16	83	Io mi meno anche quando non ho dubbi	2014-04-27 17:58:49+00	193
18	16	83	E COSI&#039; FU.	2014-04-27 17:59:01+00	194
16	16	81	[img]http://assets.vice.com/content-images/contentimage/no-slug/18a62d59aed220ff6420649cc8b6dba4.jpg[/img]	2014-04-27 17:59:07+00	195
16	16	83	NEL DUBBIO \nMENATELO	2014-04-27 17:59:21+00	196
2	16	81	[commentquote=[user]PUNCHMYDICK[/user]][img]http://assets.vice.com/content-images/contentimage/no-slug/18a62d59aed220ff6420649cc8b6dba4.jpg[/img][/commentquote]E&#039; esattamente la mia espressione dopo la spesa da MD discount :o	2014-04-27 17:59:49+00	197
2	16	83	[commentquote=[user]PUNCHMYDICK[/user]]NEL DUBBIO \nMENATELO[/commentquote][commentquote=[user]PeppaPig[/user]]Io mi meno anche quando non ho dubbi[/commentquote]	2014-04-27 18:00:05+00	198
16	16	81	Inizi a smascellare?	2014-04-27 18:00:06+00	199
2	16	81	[commentquote=[user]PUNCHMYDICK[/user]]Inizi a smascellare?[/commentquote]PEGGIO!	2014-04-27 18:00:44+00	200
1	16	84	A chiunque.	2014-04-27 18:01:09+00	201
16	16	81	Inizi ad agitare la testa come se fossi ad un rave?	2014-04-27 18:01:17+00	202
1	2	86	peppe	2014-04-27 18:02:08+00	203
16	18	85	[img]http://tosh.cc.com/blog/files/2012/11/KKKlady.jpg[/img]	2014-04-27 18:02:13+00	204
2	16	81	[commentquote=[user]PUNCHMYDICK[/user]]Inizi ad agitare la testa come se fossi ad un rave?[/commentquote]Comincio a spaccare i carrelli in testa alle cassiere e a sputare sulle nonnine che mi passano vicino	2014-04-27 18:02:40+00	205
2	2	86	[commentquote=[user]admin[/user]]peppe[/commentquote]nah[hr]e poi ho detto che sono su nerdz :V	2014-04-27 18:03:38+00	206
16	16	81	Pff nub	2014-04-27 18:04:01+00	207
1	2	86	xeno	2014-04-27 18:26:26+00	212
1	16	81	Lots of retards here.	2014-04-27 18:36:47+00	213
2	16	81	[commentquote=[user]admin[/user]]Lots of retards here.[/commentquote]tards pls, tards	2014-04-27 20:03:08+00	219
2	1	92	EBBASTA NN FR POST GEMELI ECCHECCAZZO	2014-04-27 20:04:18+00	220
16	16	84	pic || gtfo pls	2014-04-27 20:20:02+00	221
16	14	90	&lt;3	2014-04-27 20:20:29+00	222
16	1	87	io vedo gente	2014-04-27 20:20:41+00	223
1	1	87	&gt;TU\n&gt;VEDERE GENTE\n\nAHAHAHAHHAHAHAHAHAHAHAHAHA	2014-04-27 20:25:18+00	224
1	16	81	MR SWAG SPEAKING	2014-04-27 20:25:50+00	225
16	1	87	La guardo da lontano, con un binocolo.	2014-04-27 20:27:48+00	226
16	1	99	AUTISM	2014-04-27 20:28:13+00	227
2	16	84	[img]http://www.altarimini.it/immagini/news_image/peppa-pig.jpg[/img]\n[img]http://www.blogsicilia.it/wp-content/uploads/2013/11/peppa-pig-400x215.jpg[/img][hr]PS era un&#039;orgia	2014-04-27 20:35:22+00	228
2	1	99	ASSWAG	2014-04-27 20:36:11+00	229
16	16	84	[img]http://titastitas.files.wordpress.com/2013/06/peppa-pig-cazzo-big-cumshot.jpg[/img]	2014-04-27 20:36:20+00	230
2	16	101	smoke weed every day	2014-04-27 20:36:35+00	231
2	16	84	EHI KI TI PASSA CERTE IMG EH? SONO PVT	2014-04-27 20:37:35+00	232
16	16	84	HO LE MIE FONTI	2014-04-27 20:38:16+00	233
2	16	84	[commentquote=[user]PUNCHMYDICK[/user]]HO LE MIE FONTI[/commentquote]NON SARA&#039; MICA QUEL GRAN PORCO DI MIO MARITO/FIGLIO? :0	2014-04-27 20:39:53+00	234
20	4	26	TU MAMMA SE FA LE PIPPE	2014-04-27 20:49:52+00	235
2	20	102	Trova uno specchio e... SEI ARRIVATO!	2014-04-27 21:11:30+00	236
20	20	102	A BELLO DE CASA TE PISCIO MBOCCA PORCO DE DIO	2014-04-27 21:15:18+00	237
2	20	102	[commentquote=[user]SBURRO[/user]]A BELLO DE CASA TE PISCIO MBOCCA PORCO DE DIO[/commentquote]EHI IO SONO PEPPAPIG LA MAIALA PIU&#039; MAIALA CHE C&#039;E&#039;, VACCI PIANO CON GLI INSULTI!	2014-04-27 23:07:37+00	238
20	20	102	A BEDDA DE ZIO IO TE T&#039;AFFETTO NCINQUE SECONDI SI TE TROVO	2014-04-27 23:13:43+00	239
20	3	60	BEDDI, VOREI PARLA L&#039;INGLISH MA ME SA CHE NUN SE PO FA PE OGGI. NER FRATTEMPO CHE ME LO MPARE FAMOSE NA CANNETTA. DAJE MPO	2014-04-27 23:15:01+00	240
2	20	102	A BEDDO L&#039;ULTIMA PERSONA CHE HA PROVATO AD AFFETTAMME STA A FA CONGIME PE FIORI	2014-04-27 23:31:21+00	241
2	1	103	wow so COOL	2014-04-27 23:31:59+00	242
\.


--
-- Name: comments_hcid_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('comments_hcid_seq', 242, true);


--
-- Data for Name: comments_no_notify; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY comments_no_notify ("from", "to", hpid, "time") FROM stdin;
\.


--
-- Data for Name: comments_notify; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY comments_notify ("from", "to", hpid, "time") FROM stdin;
15	13	54	2014-04-26 18:08:59+00
1	4	26	2014-04-26 15:48:01+00
20	4	26	2014-04-27 20:49:52+00
20	1	26	2014-04-27 20:49:52+00
20	3	60	2014-04-27 23:15:01+00
10	1	53	2014-04-26 18:35:27+00
10	12	53	2014-04-26 18:35:27+00
1	8	39	2014-04-26 16:51:06+00
2	1	64	2014-04-27 02:02:09+00
9	1	64	2014-04-27 08:52:11+00
9	8	39	2014-04-26 16:19:12+00
20	15	60	2014-04-27 23:15:01+00
20	1	60	2014-04-27 23:15:01+00
2	20	102	2014-04-27 23:31:21+00
15	3	61	2014-04-27 10:53:27+00
15	3	60	2014-04-27 10:53:37+00
2	1	103	2014-04-27 23:31:59+00
2	1	56	2014-04-26 16:56:55+00
2	20	103	2014-04-27 23:31:59+00
1	4	19	2014-04-27 12:50:14+00
2	1	63	2014-04-27 14:44:19+00
1	3	60	2014-04-27 17:32:03+00
2	1	68	2014-04-27 17:35:33+00
1	18	81	2014-04-27 18:36:46+00
17	3	59	2014-04-27 17:47:28+00
1	17	80	2014-04-27 18:36:54+00
2	1	86	2014-04-27 19:57:20+00
2	1	82	2014-04-27 17:54:42+00
2	18	81	2014-04-27 20:03:08+00
14	4	19	2014-04-26 17:54:24+00
2	1	92	2014-04-27 20:04:18+00
16	1	84	2014-04-27 20:20:01+00
16	1	82	2014-04-27 17:56:32+00
16	14	90	2014-04-27 20:20:28+00
16	1	87	2014-04-27 20:27:47+00
2	1	84	2014-04-27 20:34:46+00
\.


--
-- Data for Name: follow; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY follow ("from", "to", notified, "time") FROM stdin;
1	4	f	2014-04-26 15:38:53+00
2	13	f	2014-04-26 16:45:44+00
4	1	f	2014-04-26 15:39:04+00
6	1	f	2014-04-26 16:00:50+00
2	1	f	2014-04-26 16:13:16+00
1	14	t	2014-04-27 19:25:19+00
13	1	t	2014-04-26 17:08:17+00
1	16	f	2014-04-27 17:51:33+00
6	10	f	2014-04-26 16:31:01+00
1	2	f	2014-04-26 16:12:54+00
13	2	f	2014-04-26 16:44:52+00
16	1	t	2014-04-27 17:57:48+00
\.


--
-- Data for Name: groups; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY groups (counter, description, owner, name, private, photo, website, goal, visible, open) FROM stdin;
2	A simple project in which I&#039;ll go to explain all the wonderful techniques available in the machine learning&#039;s field	3	Artificial Intelligence	f	\N	\N		t	f
3	MERDZilla - where we don&#039;t solve your bugs.	4	NERDZilla	f	\N	\N		t	f
4	Per tutti gli amanti degli Ananas	6	Ananas &hearts;	f	http://tarbawiyat.freehostia.com/francais/Cours3/a/ananas.jpg		Far amare gli ananas a tutti	t	t
5	.	12	CANI	f	\N	\N		t	f
6	IL GOMBLODDO	1	GOMBLODDI	f	\N	\N		t	f
1	PROGETTO	1	PROGETTO	f	http://www.matematicamente.it/forum/styles/style-matheme_se/imageset/logo.2013-200x48.png	http://www.sitoweb.info	fare cose	t	t
7	QUA SE FAMO LE CANNE ZI&#039;	20	SCALDA E ROLLA	f	\N	\N		t	f
\.


--
-- Data for Name: groups_bookmarks; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY groups_bookmarks ("from", hpid, "time") FROM stdin;
1	1	2014-04-26 16:14:29+00
6	2	2014-04-26 16:30:34+00
6	1	2014-04-26 16:30:49+00
1	3	2014-04-27 19:28:52+00
\.


--
-- Data for Name: groups_comment_thumbs; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY groups_comment_thumbs (hcid, "user", vote) FROM stdin;
\.


--
-- Data for Name: groups_comments; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY groups_comments ("from", "to", hpid, message, "time", hcid) FROM stdin;
2	1	2	WOW, &egrave; meraviglierrimo :O	2014-04-26 15:21:42+00	1
1	1	2	Non so usare windows. Non mangio le mele. In un&#039;altra vita ero Hacker, in questa sono Developer. Ho il vaffanculo facile: stammi alla larga. #DefollowMe	2014-04-26 15:21:57+00	2
1	5	7	figooooooooooooooo[hr]FIGO	2014-04-27 17:52:08+00	3
10	5	7	LOL	2014-04-27 18:38:33+00	4
1	3	3	I LOVE YOU GABE	2014-04-27 19:28:57+00	5
\.


--
-- Name: groups_comments_hcid_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('groups_comments_hcid_seq', 5, true);


--
-- Data for Name: groups_comments_no_notify; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY groups_comments_no_notify ("from", "to", hpid, "time") FROM stdin;
\.


--
-- Data for Name: groups_comments_notify; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY groups_comments_notify ("from", "to", hpid, "time") FROM stdin;
1	12	7	2014-04-27 17:52:07+00
10	12	7	2014-04-27 18:38:32+00
10	1	7	2014-04-27 18:38:32+00
1	4	3	2014-04-27 19:28:57+00
\.


--
-- Name: groups_counter_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('groups_counter_seq', 7, true);


--
-- Data for Name: groups_followers; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY groups_followers ("group", "user") FROM stdin;
2	1
4	1
\.


--
-- Data for Name: groups_lurkers; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY groups_lurkers ("user", post, "time") FROM stdin;
6	2	2014-04-26 16:30:30+00
6	1	2014-04-26 16:30:49+00
13	6	2014-04-26 16:47:00+00
13	5	2014-04-26 16:47:01+00
13	4	2014-04-26 16:47:02+00
\.


--
-- Data for Name: groups_members; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY groups_members ("group", "user") FROM stdin;
1	15
\.


--
-- Data for Name: groups_notify; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY groups_notify ("group", "to", "time") FROM stdin;
4	6	2014-04-27 19:28:43+00
\.


--
-- Data for Name: groups_posts; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY groups_posts (hpid, "from", "to", pid, message, "time", news) FROM stdin;
1	1	1	1	PROGETTO DOVE SCRIVO PROGETTO	2014-04-26 15:14:04+00	f
2	1	1	2	HO GI&Agrave; DETTO PROGETTO?	2014-04-26 15:15:49+00	f
3	4	3	1	Half Life 3 has been confirmed.	2014-04-26 15:34:17+00	t
7	12	5	1	CUI CI SONO CANI\n[yt]\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n[/yt]	2014-04-26 16:41:05+00	t
6	6	4	3	[img]http://static.pourfemme.it/pfwww/fotogallery/625X0/67021/ananas-a-fette.jpg[/img]\nOra il punto forte, ananas a fette	2014-04-26 16:29:38+00	f
5	6	4	2	[img]http://www.bzi.ro/public/upload/photos/43/ananas.jpg[/img]\nEd ecco alcuni ananas di fila	2014-04-26 16:28:54+00	f
4	6	4	1	[img]http://pharm1.pharmazie.uni-greifswald.de/systematik/7_bilder/yamasaki/yamas686.jpg[/img]\nQui possiamo vedere un esemplare tipico di Ananas	2014-04-26 16:28:14+00	f
8	1	1	3	NUOVO POST NEL PROGETTO\n	2014-04-27 17:51:18+00	f
9	1	6	1	GOMBLODDO [news]	2014-04-27 18:39:49+00	t
10	1	6	2	i post sui progetti sono be3lli	2014-04-27 19:28:23+00	f
11	1	4	4	I LOVE ANANAS. THANK YOU!	2014-04-27 19:28:43+00	f
12	1	1	4	anzi, sono bellissimi :D:D:D:D:D:D:	2014-04-27 19:29:03+00	f
13	20	7	1	IO CE METTO ER FUMO E VOI ROLLATE LE CANNE.	2014-04-27 20:49:00+00	f
\.


--
-- Name: groups_posts_hpid_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('groups_posts_hpid_seq', 13, true);


--
-- Data for Name: groups_posts_no_notify; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY groups_posts_no_notify ("user", hpid, "time") FROM stdin;
\.


--
-- Data for Name: groups_thumbs; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY groups_thumbs (hpid, "user", vote) FROM stdin;
4	1	1
6	1	-1
3	1	1
\.


--
-- Data for Name: lurkers; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY lurkers ("user", post, "time") FROM stdin;
3	16	2014-04-26 15:32:54+00
3	15	2014-04-26 15:32:55+00
1	20	2014-04-26 15:38:27+00
6	27	2014-04-26 16:02:38+00
6	35	2014-04-26 16:08:30+00
6	33	2014-04-26 16:08:32+00
6	39	2014-04-26 16:17:22+00
6	37	2014-04-26 16:18:06+00
6	44	2014-04-26 16:27:29+00
12	48	2014-04-26 16:36:47+00
1	53	2014-04-26 16:53:38+00
6	22	2014-04-26 17:00:02+00
6	2	2014-04-26 17:00:57+00
3	58	2014-04-26 18:16:36+00
\.


--
-- Data for Name: pms; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY pms ("from", "to", "time", message, read, pmid) FROM stdin;
1	12	2014-04-26 16:51:43+00	Niente overflow :&#039;)	t	16
12	1	2014-04-26 16:48:32+00	.........................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................................	f	15
4	1	2014-04-26 15:40:28+00	MMH GABEN UNLEASHED\n[img]http://i.imgur.com/fH87gyw.png[/img]	f	11
2	1	2014-04-26 15:20:58+00	TU NON SEI NESSUNO PER ME! COME TI PERMETTI?	f	2
2	1	2014-04-26 15:22:21+00	Ciao PtkDev, come va la vita? E soprattutto perch&egrave; ne hai ancora una?	f	4
2	1	2014-04-26 15:25:54+00	In realt&agrave; lo user agent sta mentendo. Non sono da windows 8.1 ma da windows 3.1 :O	f	8
16	1	2014-04-27 17:52:59+00	PACCIO H&igrave;HH&igrave;H&igrave;H\nchi &egrave; peppapig?	f	18
16	1	2014-04-27 17:57:30+00	Che figata	f	20
16	1	2014-04-27 18:01:46+00	wtf?\na cosa?	t	22
1	16	2014-04-27 17:51:41+00	HIHIHIHIHIH	f	17
1	16	2014-04-27 17:53:56+00	Sai che realmente non lo so? lel\nSo solo che &egrave; sempre online qui sopra (sul nerdz di test) il che &egrave; bello sul serio asd	f	19
1	16	2014-04-27 18:00:59+00	pls risp	f	21
1	14	2014-04-27 19:25:38+00	QUOTO TUTTO!!!	t	23
1	2	2014-04-26 15:20:07+00	MAIALA	f	1
1	2	2014-04-26 15:21:22+00	Non so usare windows. Non mangio le mele. In un&#039;altra vita ero Hacker, in questa sono Developer. Ho il vaffanculo facile: stammi alla larga. #DefollowMe	f	3
1	2	2014-04-26 15:22:51+00	Pls, CHI SEI TU?	f	5
1	2	2014-04-26 15:22:59+00	SEI IL MALE, IO LO VEDO	f	6
1	2	2014-04-26 15:23:05+00	USI WINDOWS LO USER AGENT NON MENTE	f	7
1	2	2014-04-26 15:26:21+00	SEI UN RETROPATRIK	f	9
1	4	2014-04-26 15:38:51+00	XOXO	f	10
1	4	2014-04-26 15:40:47+00	k, i need to puke right now	f	12
12	4	2014-04-26 16:46:56+00		t	13
12	4	2014-04-26 16:47:04+00	ddf	t	14
\.


--
-- Name: pms_pmid_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('pms_pmid_seq', 23, true);


--
-- Data for Name: posts; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY posts (hpid, "from", "to", pid, message, notify, "time") FROM stdin;
2	1	1	1	Postare &egrave; molto bello.	f	2014-04-26 15:03:27+00
3	1	1	2	&Egrave; davvero uno spasso fare post :&gt;	f	2014-04-26 15:03:47+00
4	1	1	3	Quando un admin si sente solo non pu&ograve; fare altro che spammare e postare.	f	2014-04-26 15:04:15+00
5	1	1	4	[img]https://fbcdn-sphotos-f-a.akamaihd.net/hphotos-ak-frc1/t1.0-9/q71/s720x720/10295706_754761757878221_576570612184366073_n.jpg[/img] SALVO AIUTAMI TU	f	2014-04-26 15:04:47+00
6	1	1	5	Sono il primo ed ultimo utente :&lt;	f	2014-04-26 15:06:01+00
8	2	2	1	Tutto in portoghese, non si capisce una minchiao	f	2014-04-26 15:10:25+00
9	1	1	6	VENITE A VEDERE IL MIO NUOVO [PROJECT]PROGETTO[/PROJECT], BELILSSIMO [PROJECT]PROGETTO[/PROJECT]. STUPENDO [PROJECT]PROGETTO[/PROJECT]	f	2014-04-26 15:14:29+00
10	1	1	7	MEGLIO DI SALVO C&#039;&Egrave; SOLO PATRICK	f	2014-04-26 15:22:36+00
12	4	4	1	[url=http://gaben.tv]My personal website[/url].	f	2014-04-26 15:26:37+00
11	1	3	1	Hi, welcome on NERDZ! How did you find this website?	f	2014-04-26 15:26:06+00
14	2	2	2	ALL HAIL THE PIG	f	2014-04-26 15:28:25+00
13	3	3	2	Hi there.\nI&#039;m mitchell and I&#039;m a computer scientist from Amsterdam.\n\nI&#039;ll try to make a post here in order to understand if this box has been correctly set up.	f	2014-04-26 15:26:43+00
15	4	4	2	I think we should rename this site to &quot;MERDZ&quot;.	f	2014-04-26 15:28:30+00
16	1	4	3	[img]http://i.imgur.com/4VkOPTx.gif[/img]\nYOU.\nARE.\nTHE.\nMAN.	f	2014-04-26 15:31:43+00
17	4	4	4	[img]http://upload.wikimedia.org/wikipedia/commons/6/66/Gabe_Newell_GDC_2010.jpg[/img]	f	2014-04-26 15:33:04+00
18	1	1	8	&gt;@beppe_grillo minaccia di uscire dall&#039;euro usando la bufala dei 50 miliardi l&#039;anno del fiscal compact.\n\nVIA VIA BEPPE	f	2014-04-26 15:33:29+00
19	1	1	9	Desktop thread? Desktop thread.\n[img]http://i.imgur.com/muyPP.png[/img]	f	2014-04-26 15:36:11+00
20	4	4	5	[url=http://freddy.niggazwithattitu.de/]Check out this website![/url]	f	2014-04-26 15:36:20+00
21	1	1	10	Non l&#039;ho mai detto. Ma mi piacciono le formiche.	f	2014-04-26 15:40:07+00
22	1	1	11	I miei posts sono pieni d&#039;amore ed odio. Dov&#039;&egrave; madalby :&lt;  :&lt; :&lt;	f	2014-04-26 15:40:27+00
23	4	4	6	You can&#039;t withstand my swagness.\n[img]https://fbcdn-sphotos-c-a.akamaihd.net/hphotos-ak-ash3/550353_521879527824004_1784603382_n.jpg[/img]	f	2014-04-26 15:41:58+00
25	5	5	1	[yt]https://www.youtube.com/watch?v=GmbEpMVqNt0[/yt]	f	2014-04-26 15:46:50+00
39	2	8	2	SPORCO IMPOSTORE! SONO IO L&#039;UNICA MAIALA QUI DENTRO, CAPITO? VAI VIA [small]xeno[/small]	f	2014-04-26 16:14:24+00
26	4	4	7	I have to go now, forever.\n[i]See you in the next era.[/i]	f	2014-04-26 15:47:25+00
38	1	2	4	que bom Peppa n&oacute;s somos amigos agora!	f	2014-04-26 16:13:57+00
27	1	5	2	Hi and welcome on NERDZ MEGANerchia! How did you find this website?	f	2014-04-26 15:48:28+00
28	5	5	3	Sto sito &egrave; nbicchiere de piscio	f	2014-04-26 15:51:35+00
29	1	6	1	REAL OR FAKE?	f	2014-04-26 15:51:46+00
31	6	6	2	Btw c&#039;&egrave; qualche problema col cambio di nick o sbaglio? asd	f	2014-04-26 15:54:13+00
32	7	7	1	HAI I&#039;M THE USER WHO LOVES TO LOG NEWS	f	2014-04-26 15:58:50+00
33	2	2	3	Una domanda: come si cambia avatar? lel	f	2014-04-26 16:02:21+00
34	1	6	3	Tu mangi le mele?	f	2014-04-26 16:02:55+00
24	1	1	12	@ * CHECKOUT MY PROFILE PAGE. UPDATED INTERESTS AND QUOTES.\n\n[ITA] Guardate il mio profilo, ho aggiornato gli interessi e le citazioni :D\n\n[DE] Banane :&gt;\n[hr] Hrvatz !! LOL!!!\n[FR] Je suis un fille fillo\n\n[PT] U SEXY MAMA BABY	f	2014-04-26 15:46:23+00
35	1	1	13	[URL]http://translate.google.it[/URL] un link utile!	f	2014-04-26 16:07:44+00
36	1	4	8	I miss you :&lt;	t	2014-04-26 16:10:38+00
37	1	8	1	NON SEI SIMPATICO TU\n\n[small]forse s&igrave;[/SMALL]	f	2014-04-26 16:12:47+00
40	9	9	1	PLS, YOUR SISTEM IS OWNED	f	2014-04-26 16:18:46+00
41	2	2	5	Il re joffrey &egrave; un figo della madonna, ho un poster gigante sul soffitto e mi masturbo ogni notte pensando a lui. &lt;3	f	2014-04-26 16:18:49+00
42	10	10	1	\\o/	f	2014-04-26 16:19:29+00
43	11	11	1	[YT]http://www.youtube.com/watch?v=Ju8Hr50Ckwk[/YT]\nCHE BRAVA ALICIA	f	2014-04-26 16:24:16+00
44	2	11	2	Ciao gufo, io sono una maiala, piacere :3	f	2014-04-26 16:25:14+00
46	7	7	2	Doch %%12now is34%% [user]Ananas[/user].	f	2014-04-26 16:32:53+00
45	2	9	2	VAI VIA PTKDEV	f	2014-04-26 16:31:39+00
48	9	9	3	SICURAMENTE QUESTO SITO SALVA LE PASSOWRD IN CHIARO	f	2014-04-26 16:35:25+00
49	12	12	1	GOMBLOTTTOF	f	2014-04-26 16:36:09+00
50	9	13	1	AAHAHHAHAHAHAHAHAHAHAH LA TUA PRIVACY &Egrave; A RISCHIO	f	2014-04-26 16:37:32+00
52	12	12	2	CIOE SECND ME PEPPE CRILLO VUOLE SL CS MEGLI PE NOI NN CM CUEI LA CSTA	f	2014-04-26 16:38:05+00
51	9	11	3	AAHAHHAHAHAHAHAHAHAHAH HO IL DUMP DEL DATABASE. JAVASCRIPQL INJECTION	f	2014-04-26 16:37:59+00
53	12	12	3	We are planning our move from MySQL on EC2 to MySQL RDS.\none of the things we do quite frequently is mysqldump to get quick snapshots of a single DB.\nI read in the documentation that RDS allows for up to 30 dbs on a single instance but I have not yet seen a way in the console to dump single DB.\nAny advice?	f	2014-04-26 16:43:35+00
54	13	13	2	[wiki=it]Risotto alla milanese[/wiki]	f	2014-04-26 16:44:00+00
56	2	2	7	Siete delle merde, dovete mettervi la board in altre lingue != (Italiano|English)	f	2014-04-26 16:45:33+00
55	13	2	6	Buona sera, signora porca	f	2014-04-26 16:45:06+00
47	2	1	14	[yt]https://www.youtube.com/watch?v=CLEtGRUrtJo&amp;feature=kp[/yt]	f	2014-04-26 16:33:13+00
57	2	13	3	[quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u]	f	2014-04-26 17:16:15+00
58	9	14	1	OH YOU NOOB	f	2014-04-26 17:57:45+00
59	15	14	2	YOU FUCKING FAKE	f	2014-04-26 18:06:29+00
60	15	3	3	Hello, can I  insult your god?	f	2014-04-26 18:07:13+00
91	1	1	22	[USER]NOT FOUND :&lt;[/user]	f	2014-04-27 19:26:33+00
92	1	1	23	[yt]https://www.youtube.com/watch?v=WULsZJxPfws[/yt]\nN E V E R - F O R G E T	f	2014-04-27 19:34:55+00
93	2	2	12	G	f	2014-04-27 20:14:24+00
62	3	3	4	[code=Fuck]\nA fuck, in the fuck, fuck a fuck in the fucking fuck\n[/code]\n\n[code=gombolo]\n[/code]	f	2014-04-26 18:16:51+00
63	2	2	8	Siete tutti dei buzzurri	f	2014-04-26 20:51:44+00
64	1	1	15	LOL ORA TARDA FTW	f	2014-04-27 00:53:04+00
65	9	9	4	No cio&egrave;, davvero yahoo!? [img]http://i.imgur.com/Gg8T4ph.png[/img]	f	2014-04-27 09:00:35+00
66	1	1	16	[img]https://pbs.twimg.com/media/BmK27EHIMAIKO0q.jpg[/img]	f	2014-04-27 09:02:50+00
61	14	15	1	FAKE	f	2014-04-26 18:15:19+00
67	15	15	2	[img]http://i.imgur.com/vrF4D09.png[/img]	f	2014-04-27 13:38:35+00
68	1	2	9	Peppa, eu realmente aprecio a sua usar ativamente esta vers&atilde;o do nerdz\n\nxoxo	f	2014-04-27 17:04:57+00
69	1	1	17	[img]http://i.imgur.com/vrF4D09.png[/img] :O	f	2014-04-27 17:30:08+00
70	1	1	18	Golang api leaked\n[code=go]package nerdz\nimport (\n        &quot;github.com/jinzhu/gorm&quot;\n        &quot;net/url&quot;\n)\n// Informations common to all the implementation of Board\ntype Info struct {\n        Id        int64\n        Owner     *User\n        Followers []*User\n        Name      string\n        Website   *url.URL\n        Image     *url.URL\n}\n// PostlistOptions is used to specify the options of a list of posts.\n// The 4 fields are documented and can be combined.\n//\n// If Following = Followers = true -&gt; show posts FROM user that I follow that follow me back (friends)\n// If Older != 0 &amp;&amp; Newer != 0 -&gt; find posts BETWEEN this 2 posts\n//\n// For example:\n// - user.GetUserHome(&amp;PostlistOptions{Followed: true, Language: &quot;en&quot;})\n// returns at most the last 20 posts from the english speaking users that I follow.\n// - user.GetUserHome(&amp;PostlistOptions{Followed: true, Following: true, Language: &quot;it&quot;, Older: 90, Newer: 50, N: 10})\n// returns at most 10 posts, from user&#039;s friends, speaking italian, between the posts with hpid 90 and 50\ntype PostlistOptions struct {\n        Following bool   // true -&gt; show posts only FROM following\n        Followers bool   // true -&gt; show posts only FROM followers\n        Language  string // if Language is a valid 2 characters identifier, show posts from users (users selected enabling/disabling following &amp; folowers) speaking that Language\n        N         int    // number of post to return (min 1, max 20)\n        Older     int64  // if specified, tells to the function using this struct to return N posts OLDER (created before) than the post with the specified &quot;Older&quot; ID\n        Newer     int64  // if specified, tells to the function using this struct to return N posts NEWER (created after) the post with the specified &quot;Newer&quot;&quot; ID\n}\n\n// Board is the representation of a generic Board.\n// Every board has its own Informations and Postlist\ntype Board interface {\n        GetInfo() *Info\n        // The return value type of GetPostlist must be changed by type assertion.\n        GetPostlist(*PostlistOptions) interface{}\n}\n\n// postlistQueryBuilder returns the same pointer passed as first argument, with new specified options setted\n// If the user parameter is present, it&#039;s intentend to be the user browsing the website.\n// So it will be used to fetch the following list -&gt; so we can easily find the posts on a bord/project/home/ecc made by the users that &quot;user&quot; is following\nfunc postlistQueryBuilder(query *gorm.DB, options *PostlistOptions, user ...*User) *gorm.DB {\n        if options == nil {\n                return query.Limit(20)\n        }\n\n        if options.N &gt; 0 &amp;&amp; options.N &lt; 20 {\n                query = query.Limit(options.N)\n        } else {\n                query = query.Limit(20)\n        }\n\n        userOK := len(user) == 1 &amp;&amp; user[0] != nil\n\n        if !options.Followers &amp;&amp; options.Following &amp;&amp; userOK { // from following + me\n                following := user[0].getNumericFollowing()\n                if len(following) != 0 {\n                        query = query.Where(&quot;\\&quot;from\\&quot; IN (? , ?)&quot;, following, user[0].Counter)\n                }\n        } else if !options.Following &amp;&amp; options.Followers &amp;&amp; userOK { //from followers + me\n                followers := user[0].getNumericFollowers()\n                if len(followers) != 0 {\n                        query = query.Where(&quot;\\&quot;from\\&quot; IN (? , ?)&quot;, followers, user[0].Counter)\n                }\n        } else if options.Following &amp;&amp; options.Followers &amp;&amp; userOK { //from friends + me\n                follows := new(UserFollow).TableName()\n                query = query.Where(&quot;\\&quot;from\\&quot; IN ( (SELECT ?) UNION  (SELECT \\&quot;to\\&quot; FROM (SELECT \\&quot;to\\&quot; FROM &quot;+follows+&quot; WHERE \\&quot;from\\&quot; = ?) AS f INNER JOIN (SELECT \\&quot;from\\&quot; FROM &quot;+follows+&quot; WHERE \\&quot;to\\&quot; = ?) AS e on f.to = e.from) )&quot;, user[0].Counter, user[0].Counter, user[0].Counter)\n        }\n\n        if options.Language != &quot;&quot; {\n                query = query.Where(&amp;User{Lang: options.Language})\n        }\n\n        if options.Older != 0 &amp;&amp; options.Newer != 0 {\n                query = query.Where(&quot;hpid BETWEEN ? AND ?&quot;, options.Newer, options.Older)\n        } else if options.Older != 0 {\n                query = query.Where(&quot;hpid &lt; ?&quot;, options.Older)\n        } else if options.Newer != 0 {\n                query = query.Where(&quot;hpid &gt; ?&quot;, options.Newer)\n        }\n\n        return query\n}[/code]	f	2014-04-27 17:31:02+00
72	1	1	19	Tutto questo &egrave; bellissimo &lt;3&lt;34	f	2014-04-27 17:31:51+00
73	2	2	10	E&#039; meraviglioso il fatto che ci sia pi&ugrave; attivit&agrave; qui che sul nerdz non farlocco lol	f	2014-04-27 17:37:03+00
74	16	16	1	LEL	f	2014-04-27 17:39:18+00
75	16	16	2	DIO	f	2014-04-27 17:41:45+00
76	16	16	3	BOIA	f	2014-04-27 17:42:27+00
77	16	16	4	MI GRATTO IL CULO E ANNUSO LA MANO	f	2014-04-27 17:42:47+00
78	2	16	5	Hola, sono la porca della situazione, piacere di conoscerti :v	f	2014-04-27 17:43:17+00
79	16	16	6	ღ Beppe ღ ha risposto 5 anni fa\nIl sesso anale non dovrebbe fare male. Se fa male lo state facendo in maniera sbagliata. Con abbastanza lubrificante e abbastanza pazienza, &egrave; possibilissimo godersi il sesso anale come una parte sicura e soddisfacente della vostra vita sessuale. Comunque, ad alcune persone non piacer&agrave; mai, e se il tuo/la tua amante &egrave; una di queste persone, rispetta i suoi limiti. Non forzarli. \nIl piacere dato dal sesso anale deriva da molti fattori. Fare qualcosa di &quot;schifoso&quot; attrae molte persone, specialmente per quanto riguarda il sesso. Fare qualcosa di diverso per mettere un po&#039; di pepe in una vita sessuale che &egrave; diventata noiosa pu&ograve; essere una ragione. E le sensazioni fisiche che si provano durante il sesso anale sono completamente differenti da qualsiasi altra cosa. Il retto &egrave; pieno di terminazioni nervose, alcune delle quali stimolano il cervello a premiare la persona con sensazioni gradevoli quando sono stimolate \nAllora innanzitutto x un rapporto anale perfetto, iniziate con un dito ben lubrificato. Lui deve far scivolare un dito dentro lentamente, lasciando che tu ti adatti. Deve tirarlo tutto fuori e rispingerlo dentro ancora. Deve lasciare il tempo al tuo ano di abituarsi a questo tipo di attivit&agrave;. Poi pu&ograve; far scivolare dentro anche un secondo dito. Poi bisogna scegliere una posizione. Molte donne vogliono stare sopra, per regolare quanto velocemente avviene la penetrazione. Ad altre piace stendersi sullo stomaco, o rannicchiarsi a mo&#039; di cane, o essere penetrate quando stanno stese sul fianco. Scegli qual&#039;&egrave; la migliore prima di iniziare. \nCome sempre, controllati. Rilassati e usa molto lubrificante. Le persone che amano il sesso anale dicono &quot;troppo lubrificante &egrave; quasi abbastanza&quot;. \nArriver&agrave; un momento in cui il tuo ano sar&agrave; abbastanza rilassato da permettere alla testa del suo pene di entrare facilmente dentro di te. Se sei completamente rilassata, dovrebbe risultare completamente indolore. Ora solo perch&eacute; &egrave; dentro di te, non c&#039;&egrave; ragione di iniziare a bombardarti come un matto. Lui deve lasciare che il tuo corpo si aggiusti. Digli di fare con calma. Eventualmente sarete entrambi pronti per qualcosa di pi&ugrave;. \nAnche se sei sicura che sia tu,sia il tuo partner non avete malattie, dovreste lo stesso usare un preservativo. Nel retto ci sono molti batteri che possono causare bruciature e uretriti del pene. \nSe vuoi usare il sesso anale come contraccettivo, non farlo. \nIl sesso anale non &egrave; un buon metodo contraccettivo. La perdita di sperma dall&#039;ano dopo il rapporto sessuale pu&ograve; gocciolare e causare quella che &egrave; chiamata una concezione &#039;splash&#039;. \nL&#039;ultimo consiglio, &egrave; quello di usare delle creme. Ne esistono di tantissime marche. (Pfizer, &egrave; una, ma ogni casa farmaceutica fa la sua). Basta chiedere in farmacia. Provare per credere. Importante &egrave; che non contengano farmaci, o sostanze sensibilizzanti, e non siano oleose. Potete chiedere anche creme per secchezza vaginale, attenzione per&ograve; che non contengano farmaci (ormoni o altro). Anche queste ce ne sono di tutte le marche. \nBuon divertimento.	f	2014-04-27 17:45:48+00
80	17	17	1	siano santificate le feste che iniziano con M. urliamo amen fedeli volgendo lo sguardo a un futuro pi&ugrave; mela!	f	2014-04-27 17:46:51+00
81	16	16	7	SOPRA IL LIVELLO DEL MARE\nTANTA MD PUOI TROVARE	f	2014-04-27 17:47:43+00
82	1	16	8	CIAO PUNCH	f	2014-04-27 17:51:05+00
83	16	16	9	NEL DUBBIO\nMENA	f	2014-04-27 17:58:05+00
84	16	16	10	A CHI E&#039; MAI CAPITATO DI SCOREGGIARE DURANTE UN RAPPORTO SESSUALE?	f	2014-04-27 18:00:55+00
86	2	2	11	Indovinello: chi sono su nerdz?	f	2014-04-27 18:01:36+00
85	1	18	1	OMG	f	2014-04-27 18:01:27+00
87	1	1	20	io faccio cose	f	2014-04-27 18:31:53+00
88	1	1	21	ღ Beppe ღ ღ Beppe ღ ღ Beppe ღ	f	2014-04-27 18:37:16+00
89	10	10	2	[list start=&quot;[0-9]+&quot;]\n[*] 1\n[*] 2\n[/list]	f	2014-04-27 18:47:30+00
90	14	14	3	Quando ti rendi conto di avere pi&ugrave; notifiche qui che su nerdz capisci che fai schifo	f	2014-04-27 19:15:26+00
94	2	2	13	A	f	2014-04-27 20:14:45+00
95	2	2	14	W	f	2014-04-27 20:15:05+00
96	2	2	15	S	f	2014-04-27 20:15:24+00
97	1	1	24	S	f	2014-04-27 20:21:24+00
98	1	1	25	A	f	2014-04-27 20:21:44+00
99	1	1	26	[img]http://i.imgur.com/nFyEYU0.png[/img]	f	2014-04-27 20:23:27+00
100	1	19	1	Ciao, bel nick :D:D:D:D::D	t	2014-04-27 20:24:21+00
101	16	16	11	[img]http://cdn.buzznet.com/assets/users16/geryawn/default/kitty-mindless-self-indulgence-stoned--large-msg-127354749391.jpg[/img]	f	2014-04-27 20:29:32+00
102	20	20	1	A ZII, NDO STA ER BAGNO?	f	2014-04-27 20:51:44+00
103	20	1	27	A NOBODY, TOLTO CHE ME STO A MPARA L&#039;INGLESE, ME DEVI ATTIVA L&#039;HTML CHE CE DEVO METTE LE SCRITTE FIGHE. VE QUA\n[code=html]&lt;marquee width=&quot;100%&quot; behavior=&quot;scroll&quot; scrollamount=&quot;5&quot; direction=&quot;left&quot;&gt;&lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/1/t.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/1/e.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/-.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/1/p.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/1/i.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/1/a.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/1/c.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/1/e.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/-.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/1/e.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/1/r.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/-.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/1/c.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/1/a.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/1/z.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/1/z.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/1/o.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;/marquee&gt;[/code]	t	2014-04-27 23:18:09+00
\.


--
-- Name: posts_hpid_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('posts_hpid_seq', 103, true);


--
-- Data for Name: posts_no_notify; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY posts_no_notify ("user", hpid, "time") FROM stdin;
3	13	2014-04-26 15:34:04+00
2	12	2014-04-26 15:46:11+00
1	38	2014-04-26 16:15:12+00
\.


--
-- Data for Name: profiles; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY profiles (counter, remote_addr, http_user_agent, website, quotes, biography, interests, github, skype, jabber, yahoo, userscript, template, mobile_template, dateformat, facebook, twitter, steam, push, pushregtime) FROM stdin;
14	2.237.93.106	Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/33.0.1750.152 Safari/537.36										0	1	d/m/Y, H:i				f	2014-04-26 17:52:37+00
15	83.139.197.4	Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.132 Safari/537.36										0	1	d/m/Y, H:i				f	2014-04-26 18:04:42+00
16	2.239.241.177	Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.116 Safari/537.36										0	1	d/m/Y, H:i				f	2014-04-27 17:38:56+00
4	79.33.146.217	Mozilla/5.0 (Windows NT 6.3; WOW64; rv:31.0) Gecko/20100101 Firefox/31.0										0	1	d/m/Y, H:i				f	2014-04-26 15:26:13+00
6	95.245.14.63	Mozilla/5.0 (Windows NT 6.1; rv:28.0) Gecko/20100101 Firefox/28.0										3	1	d/m/Y, H:i				f	2014-04-26 15:51:20+00
5	93.36.131.17	Mozilla/5.0 (X11; Linux i686) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.116 Safari/537.36										0	1	d/m/Y, H:i				f	2014-04-26 15:45:31+00
12	37.116.231.13	Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.116 Safari/537.36										0	1	d/m/Y, H:i				f	2014-04-26 16:35:34+00
7	87.4.110.105	Mozilla/5.0 (X11; Linux x86_64; rv:28.0) Gecko/20100101 Firefox/28.0				log log						0	1	d/m/Y, H:i				f	2014-04-26 15:57:46+00
13	95.250.52.116	Mozilla/5.0 (Windows NT 6.1; rv:28.0) Gecko/20100101 Firefox/28.0										0	1	d/m/Y, H:i				f	2014-04-26 16:35:57+00
1	83.139.197.4	Mozilla/5.0 (X11; Linux x86_64; rv:28.0) Gecko/20100101 Firefox/28.0	http://www.sitoweb.info	Non so usare windows. Non mangio le mele. In un&#039;altra vita ero Hacker, in questa sono Developer. Ho il vaffanculo facile: stammi alla larga. #DefollowMe	Non so usare windows. Non mangio le mele. In un&#039;altra vita ero Hacker, in questa sono Developer. Ho il vaffanculo facile: stammi alla larga. #DefollowMe	PATRIK	http://github.com/nerdzeu	spettacolo	email@bellissimadavve.ro			0	1	d/m/Y, H:i	https://www.facebook.com/profile.php?id=1111121111111	https://twitter.com/bellissimo_profilo	facciocose belle	f	2014-04-26 15:03:16+00
10	95.244.125.227	Mozilla/5.0 (Windows NT 6.3; WOW64; rv:28.0) Gecko/20100101 Firefox/28.0										0	1	d/m/Y, H:i				f	2014-04-26 16:18:46+00
8	95.250.52.116	Mozilla/5.0 (Windows NT 6.1; rv:28.0) Gecko/20100101 Firefox/28.0										0	1	d/m/Y, H:i				f	2014-04-26 16:10:45+00
3	95.252.250.109	Mozilla/5.0 (X11; Linux x86_64; rv:28.0) Gecko/20100101 Firefox/28.0										0	1	d/m/Y, H:i				f	2014-04-26 15:25:21+00
19	79.6.109.155	Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.116 Safari/537.36										0	1	d/m/Y, H:i				f	2014-04-27 18:23:14+00
17	79.6.109.155	Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.116 Safari/537.36										0	1	d/m/Y, H:i				f	2014-04-27 17:45:39+00
11	93.50.34.60	Mozilla/5.0 (Windows NT 6.3; WOW64; rv:28.0) Gecko/20100101 Firefox/28.0										0	1	d/m/Y, H:i				f	2014-04-26 16:23:48+00
2	79.9.87.56	Mozilla/5.0 (Windows NT 6.3; WOW64; rv:28.0) Gecko/20100101 Firefox/28.0										0	1	d/m/Y, H:i				f	2014-04-26 15:09:06+00
18	79.6.109.155	Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.116 Safari/537.36										0	1	d/m/Y, H:i				f	2014-04-27 17:49:57+00
9	79.6.178.60	Mozilla/5.0 (X11; Linux x86_64; rv:28.0) Gecko/20100101 Firefox/28.0										0	1	d/m/Y, H:i				f	2014-04-26 16:18:18+00
20	185.5.60.120	Mozilla/5.0 (Windows NT 6.1; WOW64; rv:26.0) Gecko/20100101 Firefox/26.0										0	1	d/m/Y, H:i				f	2014-04-27 20:47:11+00
\.


--
-- Name: profiles_counter_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('profiles_counter_seq', 20, true);


--
-- Data for Name: thumbs; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY thumbs (hpid, "user", vote) FROM stdin;
3	2	-1
8	1	-1
13	3	-1
31	6	0
35	6	1
35	1	1
34	1	1
49	9	1
51	12	1
50	6	-1
51	6	-1
50	13	-1
51	13	-1
50	2	-1
49	12	1
54	6	1
54	13	1
56	6	-1
53	1	1
3	6	-1
2	6	-1
4	6	-1
5	6	-1
6	6	-1
9	6	-1
10	6	-1
18	6	-1
19	6	-1
21	6	-1
22	6	-1
24	6	-1
47	6	-1
2	2	-1
4	2	-1
5	2	-1
6	2	-1
8	2	1
9	2	-1
10	2	-1
11	2	-1
13	2	-1
14	2	1
18	2	-1
19	2	-1
21	2	-1
22	2	-1
24	2	-1
25	2	-1
27	2	-1
28	2	-1
29	2	-1
31	2	-1
33	2	1
34	2	-1
35	2	-1
37	2	-1
38	2	-1
39	2	1
40	2	-1
41	2	1
42	2	-1
43	2	-1
44	2	1
45	2	1
47	2	1
48	2	-1
49	2	-1
51	2	-1
52	2	-1
53	2	-1
54	2	-1
55	2	-1
56	2	1
57	2	1
58	2	-1
59	2	-1
60	2	-1
61	2	-1
62	2	-1
55	6	1
53	10	-1
63	2	1
66	1	1
18	1	1
93	2	1
94	2	1
95	2	1
96	2	1
98	1	1
97	1	1
12	20	-1
15	20	-1
13	20	-1
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY users (counter, last, notify_story, private, lang, username, password, name, surname, email, gender, birth_date, board_lang, timezone, viewonline) FROM stdin;
14	2014-04-27 19:16:04+00	{"0":{"from":17,"from_user":"Mgonad","to":14,"to_user":"mcelloni","post_from_user":"ges&ugrave;3","post_from":15,"pid":2,"datetime":"11:47","cmp":"1398620848","board":false,"project":false},"1":{"from":1,"from_user":"admin","to":1,"to_user":"admin","post_from_user":"admin","post_from":1,"pid":9,"datetime":"06:50","cmp":"1398603014","board":false,"project":false},"2":{"from":15,"from_user":"ges&ugrave;3","to":15,"to_user":"ges&ugrave;3","post_from_user":"mcelloni","post_from":14,"pid":1,"datetime":"04:53","cmp":"1398596007","board":false,"project":false},"3":{"from":2,"from_user":"PeppaPig","to":15,"to_user":"ges&ugrave;3","post_from_user":"mcelloni","post_from":14,"pid":1,"datetime":"12:17","cmp":"1398536253","board":false,"project":false},"4":{"from":3,"from_user":"mitchell","to":14,"to_user":"mcelloni","post_from_user":"ges&ugrave;3","post_from":15,"pid":2,"datetime":"12:16","cmp":"1398536187","board":false,"project":false},"5":{"from":3,"from_user":"mitchell","to":15,"to_user":"ges&ugrave;3","post_from_user":"mcelloni","post_from":14,"pid":1,"datetime":"12:16","cmp":"1398536175","board":false,"project":false},"6":{"from":2,"from_user":"PeppaPig","to":14,"to_user":"mcelloni","post_from_user":"ges&ugrave;3","post_from":15,"pid":2,"datetime":"12:14","cmp":"1398536085","board":false,"project":false},"7":{"from":9,"from_user":"&lt;script&gt;alert(1)","to":14,"to_user":"mcelloni","pid":1,"datetime":"11:57","cmp":"1398535065","board":true,"project":false},"8":{"from":15,"from_user":"ges&ugrave;3","to":14,"to_user":"mcelloni","pid":2,"datetime":"12:06","cmp":"1398535589","board":true,"project":false}}	f	it	mcelloni	8fe455fa6cde53680789308ff66624bc886bfef7	marco	celloni	mcelloni@celle.cz	t	1995-05-03	it	America/Cambridge_Bay	t
20	2014-04-27 23:23:44+00	{"0":{"from":2,"from_user":"PeppaPig","to":20,"to_user":"SBURRO","post_from_user":"SBURRO","post_from":20,"pid":1,"datetime":"23:11","cmp":"1398633089","board":false,"project":false}}	f	en	SBURRO	4f2409154c911794cc36ce1d4180738891ef8ec2	NEL	CULO	shura1991@gmail.com	t	1988-01-01	en	Europe/Berlin	t
2	2014-04-27 23:45:14+00	{"0":{"from":20,"from_user":"SBURRO","to":20,"to_user":"SBURRO","post_from_user":"SBURRO","post_from":20,"pid":1,"datetime":"01:13","cmp":"1398640423","board":false,"project":false},"1":{"from":20,"from_user":"SBURRO","to":20,"to_user":"SBURRO","post_from_user":"SBURRO","post_from":20,"pid":1,"datetime":"27\\/04\\/2014, 23:15","cmp":"1398633318","board":false,"project":false},"2":{"from":16,"from_user":"PUNCHMYDICK","to":16,"to_user":"PUNCHMYDICK","post_from_user":"PUNCHMYDICK","post_from":16,"pid":10,"datetime":"22:38","cmp":"1398631095","board":false,"project":false},"3":{"from":16,"from_user":"PUNCHMYDICK","to":16,"to_user":"PUNCHMYDICK","post_from_user":"PUNCHMYDICK","post_from":16,"pid":10,"datetime":"22:36","cmp":"1398630979","board":false,"project":false},"4":{"from":1,"from_user":"admin","to":16,"to_user":"PUNCHMYDICK","post_from_user":"PUNCHMYDICK","post_from":16,"pid":7,"datetime":"22:25","cmp":"1398630349","board":false,"project":false},"5":{"from":16,"from_user":"PUNCHMYDICK","to":16,"to_user":"PUNCHMYDICK","post_from_user":"PUNCHMYDICK","post_from":16,"pid":10,"datetime":"22:20","cmp":"1398630001","board":false,"project":false},"6":{"from":1,"from_user":"admin","to":16,"to_user":"PUNCHMYDICK","post_from_user":"PUNCHMYDICK","post_from":16,"pid":7,"datetime":"20:36","cmp":"1398623806","board":false,"project":false},"7":{"from":1,"from_user":"admin","to":2,"to_user":"PeppaPig","post_from_user":"PeppaPig","post_from":2,"pid":11,"datetime":"20:26","cmp":"1398623185","board":false,"project":false},"8":{"from":16,"from_user":"PUNCHMYDICK","to":16,"to_user":"PUNCHMYDICK","post_from_user":"PUNCHMYDICK","post_from":16,"pid":10,"datetime":"20:08","cmp":"1398622106","board":false,"project":false},"9":{"from":16,"from_user":"PUNCHMYDICK","to":16,"to_user":"PUNCHMYDICK","post_from_user":"PUNCHMYDICK","post_from":16,"pid":7,"datetime":"20:04","cmp":"1398621841","board":false,"project":false},"10":{"from":1,"from_user":"admin","to":2,"to_user":"PeppaPig","post_from_user":"PeppaPig","post_from":2,"pid":11,"datetime":"20:02","cmp":"1398621727","board":false,"project":false},"11":{"from":16,"from_user":"PUNCHMYDICK","to":16,"to_user":"PUNCHMYDICK","post_from_user":"PUNCHMYDICK","post_from":16,"pid":7,"datetime":"20:01","cmp":"1398621676","board":false,"project":false},"12":{"from":16,"from_user":"PUNCHMYDICK","to":16,"to_user":"PUNCHMYDICK","post_from_user":"PUNCHMYDICK","post_from":16,"pid":7,"datetime":"20:00","cmp":"1398621606","board":false,"project":false},"13":{"from":16,"from_user":"PUNCHMYDICK","to":16,"to_user":"PUNCHMYDICK","post_from_user":"PUNCHMYDICK","post_from":16,"pid":9,"datetime":"19:59","cmp":"1398621560","board":false,"project":false},"14":{"from":16,"from_user":"PUNCHMYDICK","to":16,"to_user":"PUNCHMYDICK","post_from_user":"PUNCHMYDICK","post_from":16,"pid":7,"datetime":"19:59","cmp":"1398621546","board":false,"project":false},"15":{"from":18,"from_user":"kkklub","to":16,"to_user":"PUNCHMYDICK","post_from_user":"PUNCHMYDICK","post_from":16,"pid":9,"datetime":"19:59","cmp":"1398621540","board":false,"project":false}}	f	pt	PeppaPig	7e833b1c0406a1a5ee75f094fefb9899a52792b6	Giuseppina	Maiala	m1n61ux@gmail.com	f	1966-06-06	pt	Europe/Rome	t
17	2014-04-27 17:48:42+00	\N	f	it	Mgonad	785a6c234db7fd83a02a568e88b65ef06073dc61	Manatma	Gonads	carne@yopmail.com	t	2009-03-13	it	Africa/Abidjan	t
3	2014-04-26 19:00:50+00	{"0":{"from":2,"from_user":"PeppaPig","to":15,"to_user":"ges&ugrave;3","post_from_user":"mcelloni","post_from":14,"pid":1,"datetime":"20:17","cmp":"1398536253","board":false,"project":false},"1":{"from":15,"from_user":"ges&ugrave;3","to":"3","to_user":"mitchell","pid":3,"datetime":"20:07","cmp":"1398535633","board":true,"project":false},"2":{"from":1,"from_user":"admin","to":3,"to_user":"mitchell","post_from_user":"mitchell","post_from":3,"pid":2,"datetime":"17:32","cmp":"1398526369","board":false,"project":false},"3":{"from":2,"from_user":"PeppaPig","to":3,"to_user":"mitchell","post_from_user":"mitchell","post_from":3,"pid":2,"datetime":"17:30","cmp":"1398526207","board":false,"project":false},"4":{"from":2,"from_user":"PeppaPig","to":3,"to_user":"mitchell","post_from_user":"mitchell","post_from":3,"pid":2,"datetime":"17:29","cmp":"1398526143","board":false,"project":false},"5":{"from":1,"from_user":"admin","to":3,"to_user":"mitchell","pid":1,"datetime":"17:26","cmp":"1398525966","board":true,"project":false}}	f	en	mitchell	cf60ae0a7b2c5d57494755eec0e56113568aa6eb	Mitchell	Armand	alessandro.suglia@yahoo.com	t	2009-04-03	en	Europe/Amsterdam	t
1	2014-04-28 08:10:20+00	{"0":{"from":2,"from_user":"PeppaPig","to":1,"to_user":"admin","pid":14,"datetime":"16:33","cmp":"1398529993","board":true,"project":false},"1":{"from":9,"from_user":"&lt;script&gt;alert(1)","to":8,"to_user":"L&#039;Altissimo Porco","post_from_user":"PeppaPig","post_from":2,"pid":2,"datetime":"16:19","cmp":"1398529152","board":false,"project":false},"2":{"from":8,"from_user":"L&#039;Altissimo Porco","to":8,"to_user":"L&#039;Altissimo Porco","post_from_user":"PeppaPig","post_from":2,"pid":2,"datetime":"16:16","cmp":"1398529010","board":false,"project":false},"3":{"follow":true,"from":2,"from_user":"PeppaPig","datetime":"16:13","cmp":"1398528796"},"4":{"from":8,"from_user":"L&#039;Altissimo Porco","to":2,"to_user":"PeppaPig","post_from_user":"PeppaPig","post_from":2,"pid":3,"datetime":"16:12","cmp":"1398528758","board":false,"project":false},"5":{"from":2,"from_user":"PeppaPig","to":2,"to_user":"PeppaPig","post_from_user":"PeppaPig","post_from":2,"pid":3,"datetime":"16:11","cmp":"1398528706","board":false,"project":false},"6":{"from":2,"from_user":"PeppaPig","to":1,"to_user":"admin","post_from_user":"admin","post_from":1,"pid":12,"datetime":"16:09","cmp":"1398528570","board":false,"project":false},"7":{"from":2,"from_user":"PeppaPig","to":1,"to_user":"admin","post_from_user":"admin","post_from":1,"pid":13,"datetime":"16:09","cmp":"1398528547","board":false,"project":false},"8":{"from":2,"from_user":"PeppaPig","to":1,"to_user":"admin","post_from_user":"admin","post_from":1,"pid":12,"datetime":"16:07","cmp":"1398528466","board":false,"project":false},"9":{"from":6,"from_user":"Doch","to":6,"to_user":"Doch","post_from_user":"Doch","post_from":6,"pid":2,"datetime":"16:07","cmp":"1398528453","board":false,"project":false},"10":{"from":2,"from_user":"PeppaPig","to":1,"to_user":"admin","post_from_user":"admin","post_from":1,"pid":12,"datetime":"16:04","cmp":"1398528295","board":false,"project":false},"11":{"from":6,"from_user":"Doch","to":6,"to_user":"Doch","post_from_user":"admin","post_from":1,"pid":3,"datetime":"16:04","cmp":"1398528287","board":false,"project":false},"12":{"from":2,"from_user":"PeppaPig","to":6,"to_user":"Doch","post_from_user":"admin","post_from":1,"pid":3,"datetime":"16:03","cmp":"1398528238","board":false,"project":false},"13":{"from":6,"from_user":"Doch","to":6,"to_user":"Doch","post_from_user":"Doch","post_from":6,"pid":2,"datetime":"16:03","cmp":"1398528227","board":false,"project":false},"14":{"from":6,"from_user":"Doch","to":6,"to_user":"Doch","post_from_user":"admin","post_from":1,"pid":3,"datetime":"16:03","cmp":"1398528203","board":false,"project":false},"15":{"follow":true,"from":6,"from_user":"Doch","datetime":"16:00","cmp":"1398528050"},"16":{"from":6,"from_user":"Doch","to":6,"to_user":"Doch","post_from_user":"admin","post_from":1,"pid":1,"datetime":"15:59","cmp":"1398527971","board":false,"project":false},"17":{"from":2,"from_user":"PeppaPig","to":1,"to_user":"admin","post_from_user":"admin","post_from":1,"pid":12,"datetime":"15:58","cmp":"1398527908","board":false,"project":false}}	t	it	admin	dd94709528bb1c83d08f3088d4043f4742891f4f	admin	admin	admin@admin.net	t	2011-02-01	it	Europe/Rome	t
9	2014-04-27 09:01:59+00	{"0":{"from":11,"from_user":"owl","to":11,"to_user":"owl","post_from_user":"&lt;script&gt;alert(1)","post_from":9,"pid":3,"datetime":"16:39","cmp":"1398530346","board":false,"project":false},"1":{"from":2,"from_user":"PeppaPig","to":9,"to_user":"&lt;script&gt;alert(1)","post_from_user":"PeppaPig","post_from":2,"pid":2,"datetime":"16:39","cmp":"1398530344","board":false,"project":false},"2":{"from":1,"from_user":"admin","to":8,"to_user":"L&#039;Altissimo Porco","post_from_user":"PeppaPig","post_from":2,"pid":2,"datetime":"16:51","cmp":"1398531066","board":false,"project":false},"3":{"from":2,"from_user":"PeppaPig","to":12,"to_user":"Helium","post_from_user":"Helium","post_from":12,"pid":1,"datetime":"16:43","cmp":"1398530581","board":false,"project":false},"4":{"from":2,"from_user":"PeppaPig","to":13,"to_user":"Albero Azzurro","post_from_user":"&lt;script&gt;alert(1)","post_from":9,"pid":1,"datetime":"16:38","cmp":"1398530316","board":false,"project":false},"5":{"from":2,"from_user":"PeppaPig","to":12,"to_user":"Helium","post_from_user":"Helium","post_from":12,"pid":1,"datetime":"16:38","cmp":"1398530296","board":false,"project":false},"6":{"from":2,"from_user":"PeppaPig","to":9,"to_user":"&lt;script&gt;alert(1)","post_from_user":"PeppaPig","post_from":2,"pid":2,"datetime":"16:37","cmp":"1398530259","board":false,"project":false},"7":{"from":13,"from_user":"Albero Azzurro","to":12,"to_user":"Helium","post_from_user":"Helium","post_from":12,"pid":1,"datetime":"16:37","cmp":"1398530240","board":false,"project":false},"8":{"from":2,"from_user":"PeppaPig","to":9,"to_user":"&lt;script&gt;alert(1)","post_from_user":"PeppaPig","post_from":2,"pid":2,"datetime":"16:35","cmp":"1398530152","board":false,"project":false},"9":{"from":2,"from_user":"PeppaPig","to":"9","to_user":"&lt;script&gt;alert(1)","pid":2,"datetime":"16:31","cmp":"1398529899","board":true,"project":false}}	f	it	&lt;script&gt;alert(1)	6168e894055b1da930c6418a1fdfa955884254e6	&lt;?php die(&quot;HACKED!!&quot;); ?&gt;	&lt;?php die(&quot;HACKED!!&quot;); ?&gt;	HACKER@HEKKER.NET	t	2008-02-03	it	Africa/Banjul	t
16	2014-04-27 21:24:44+00	{"0":{"from":2,"from_user":"PeppaPig","to":16,"to_user":"PUNCHMYDICK","post_from_user":"PUNCHMYDICK","post_from":16,"pid":10,"datetime":"20:39","cmp":"1398631192","board":false,"project":false},"1":{"from":2,"from_user":"PeppaPig","to":16,"to_user":"PUNCHMYDICK","post_from_user":"PUNCHMYDICK","post_from":16,"pid":10,"datetime":"20:37","cmp":"1398631054","board":false,"project":false},"2":{"from":2,"from_user":"PeppaPig","to":16,"to_user":"PUNCHMYDICK","post_from_user":"PUNCHMYDICK","post_from":16,"pid":11,"datetime":"20:36","cmp":"1398630994","board":false,"project":false},"3":{"from":2,"from_user":"PeppaPig","to":1,"to_user":"admin","post_from_user":"admin","post_from":1,"pid":26,"datetime":"20:36","cmp":"1398630970","board":false,"project":false},"4":{"from":2,"from_user":"PeppaPig","to":16,"to_user":"PUNCHMYDICK","post_from_user":"PUNCHMYDICK","post_from":16,"pid":10,"datetime":"20:34","cmp":"1398630886","board":false,"project":false},"5":{"from":1,"from_user":"admin","to":16,"to_user":"PUNCHMYDICK","post_from_user":"PUNCHMYDICK","post_from":16,"pid":7,"datetime":"20:25","cmp":"1398630349","board":false,"project":false},"6":{"from":1,"from_user":"admin","to":1,"to_user":"admin","post_from_user":"admin","post_from":1,"pid":20,"datetime":"20:25","cmp":"1398630317","board":false,"project":false},"7":{"from":2,"from_user":"PeppaPig","to":16,"to_user":"PUNCHMYDICK","post_from_user":"PUNCHMYDICK","post_from":16,"pid":7,"datetime":"20:03","cmp":"1398628988","board":false,"project":false},"8":{"from":1,"from_user":"admin","to":16,"to_user":"PUNCHMYDICK","post_from_user":"PUNCHMYDICK","post_from":16,"pid":6,"datetime":"18:37","cmp":"1398623826","board":false,"project":false},"9":{"from":1,"from_user":"admin","to":16,"to_user":"PUNCHMYDICK","post_from_user":"PUNCHMYDICK","post_from":16,"pid":7,"datetime":"18:36","cmp":"1398623806","board":false,"project":false},"10":{"from":2,"from_user":"PeppaPig","to":16,"to_user":"PUNCHMYDICK","post_from_user":"PUNCHMYDICK","post_from":16,"pid":10,"datetime":"18:17","cmp":"1398622671","board":false,"project":false},"11":{"from":18,"from_user":"kkklub","to":18,"to_user":"kkklub","post_from_user":"admin","post_from":1,"pid":1,"datetime":"18:11","cmp":"1398622287","board":false,"project":false},"12":{"from":18,"from_user":"kkklub","to":18,"to_user":"kkklub","post_from_user":"admin","post_from":1,"pid":1,"datetime":"18:09","cmp":"1398622161","board":false,"project":false},"13":{"from":2,"from_user":"PeppaPig","to":16,"to_user":"PUNCHMYDICK","post_from_user":"PUNCHMYDICK","post_from":16,"pid":10,"datetime":"18:06","cmp":"1398622010","board":false,"project":false},"14":{"from":2,"from_user":"PeppaPig","to":16,"to_user":"PUNCHMYDICK","post_from_user":"PUNCHMYDICK","post_from":16,"pid":10,"datetime":"18:06","cmp":"1398621983","board":false,"project":false},"15":{"from":2,"from_user":"PeppaPig","to":16,"to_user":"PUNCHMYDICK","post_from_user":"PUNCHMYDICK","post_from":16,"pid":7,"datetime":"18:02","cmp":"1398621760","board":false,"project":false}}	f	it	PUNCHMYDICK	48efc4851e15940af5d477d3c0ce99211a70a3be	PUNCH	MYDICK	mad_alby@hotmail.it	t	1986-05-07	it	Africa/Abidjan	t
18	2014-04-27 18:22:06+00	{"0":{"from":1,"from_user":"admin","to":18,"to_user":"kkklub","pid":1,"datetime":"19:01","cmp":"1398621687","board":true,"project":false},"1":{"from":2,"from_user":"PeppaPig","to":16,"to_user":"PUNCHMYDICK","post_from_user":"PUNCHMYDICK","post_from":16,"pid":9,"datetime":"19:00","cmp":"1398621604","board":false,"project":false},"2":{"from":2,"from_user":"PeppaPig","to":16,"to_user":"PUNCHMYDICK","post_from_user":"PUNCHMYDICK","post_from":16,"pid":7,"datetime":"18:59","cmp":"1398621589","board":false,"project":false},"3":{"from":16,"from_user":"PUNCHMYDICK","to":16,"to_user":"PUNCHMYDICK","post_from_user":"PUNCHMYDICK","post_from":16,"pid":9,"datetime":"18:59","cmp":"1398621560","board":false,"project":false},"4":{"from":16,"from_user":"PUNCHMYDICK","to":16,"to_user":"PUNCHMYDICK","post_from_user":"PUNCHMYDICK","post_from":16,"pid":7,"datetime":"18:59","cmp":"1398621546","board":false,"project":false},"5":{"from":16,"from_user":"PUNCHMYDICK","to":18,"to_user":"kkklub","post_from_user":"admin","post_from":1,"pid":1,"datetime":"19:02","cmp":"1398621733","board":false,"project":false},"6":{"from":2,"from_user":"PeppaPig","to":16,"to_user":"PUNCHMYDICK","post_from_user":"PUNCHMYDICK","post_from":16,"pid":7,"datetime":"18:58","cmp":"1398621499","board":false,"project":false},"7":{"from":2,"from_user":"PeppaPig","to":16,"to_user":"PUNCHMYDICK","post_from_user":"PUNCHMYDICK","post_from":16,"pid":7,"datetime":"18:55","cmp":"1398621340","board":false,"project":false}}	f	it	kkklub	835c8ecbb6255e73ffcadb25e8b1ffd5bfaae5c4	ppp	mmm	dgh@fecciamail.it	f	2007-05-03	it	Africa/Casablanca	t
4	2014-04-26 15:47:19+00	{"0":{"from":1,"from_user":"admin","to":1,"to_user":"admin","post_from_user":"admin","post_from":1,"pid":9,"datetime":"15:45","cmp":"1398527155","board":false,"project":false},"1":{"from":1,"from_user":"admin","to":1,"to_user":"admin","post_from_user":"admin","post_from":1,"pid":11,"datetime":"15:45","cmp":"1398527137","board":false,"project":false},"2":{"from":2,"from_user":"PeppaPig","to":1,"to_user":"admin","post_from_user":"admin","post_from":1,"pid":9,"datetime":"15:45","cmp":"1398527123","board":false,"project":false},"3":{"from":1,"from_user":"admin","to":4,"to_user":"Gaben","post_from_user":"Gaben","post_from":4,"pid":6,"datetime":"15:44","cmp":"1398527083","board":false,"project":false},"4":{"from":1,"from_user":"admin","to":4,"to_user":"Gaben","post_from_user":"Gaben","post_from":4,"pid":6,"datetime":"15:43","cmp":"1398527007","board":false,"project":false},"5":{"from":1,"from_user":"admin","to":1,"to_user":"admin","post_from_user":"admin","post_from":1,"pid":9,"datetime":"15:39","cmp":"1398526790","board":false,"project":false},"6":{"follow":true,"from":1,"from_user":"admin","datetime":"15:38","cmp":"1398526733"},"7":{"from":1,"from_user":"admin","to":1,"to_user":"admin","post_from_user":"admin","post_from":1,"pid":9,"datetime":"15:38","cmp":"1398526693","board":false,"project":false},"8":{"from":1,"from_user":"admin","to":4,"to_user":"Gaben","pid":3,"datetime":"15:31","cmp":"1398526303","board":true,"project":false},"9":{"from":1,"from_user":"admin","to":4,"to_user":"Gaben","post_from_user":"Gaben","post_from":4,"pid":1,"datetime":"15:31","cmp":"1398526284","board":false,"project":false},"10":{"from":1,"from_user":"admin","to":4,"to_user":"Gaben","post_from_user":"Gaben","post_from":4,"pid":2,"datetime":"15:30","cmp":"1398526248","board":false,"project":false},"11":{"from":2,"from_user":"PeppaPig","to":4,"to_user":"Gaben","post_from_user":"Gaben","post_from":4,"pid":1,"datetime":"15:29","cmp":"1398526175","board":false,"project":false},"12":{"from":1,"from_user":"admin","to":4,"to_user":"Gaben","post_from_user":"Gaben","post_from":4,"pid":2,"datetime":"15:28","cmp":"1398526125","board":false,"project":false},"13":{"from":1,"from_user":"admin","to":4,"to_user":"Gaben","post_from_user":"Gaben","post_from":4,"pid":1,"datetime":"15:28","cmp":"1398526088","board":false,"project":false}}	f	en	Gaben	a2edce3ae8a6e9a7ed627a9c1ea4bb9e54bd1bd0	Gabe	Newell	gaben@valve.net	t	1962-11-03	en	UTC	t
7	2014-04-26 15:58:56+00	\N	f	it	newsnews	5318d1471836d989b0cb3dc0816fb380e14c379e	newsnews	newsnews	newsnews@newsnews.net	t	2007-05-03	it	UTC	t
5	2014-04-26 16:07:32+00	{"0":{"from":1,"from_user":"admin","to":5,"to_user":"MegaNerchia","post_from_user":"admin","post_from":1,"pid":2,"datetime":"15:50","cmp":"1398527447","board":false,"project":false},"1":{"from":1,"from_user":"admin","to":5,"to_user":"MegaNerchia","pid":2,"datetime":"15:48","cmp":"1398527308","board":true,"project":false}}	f	en	MegaNerchia	74359506411a8497363b18248bee882b98fc2588	Mega	Nerchia	nerchia@mega.co.nz	t	2013-01-01	en	Africa/Abidjan	t
19	2014-04-27 19:10:15+00	\N	f	it	sbattiman	9d216b8d2e3f7203fa887cb3971d018181d80422	sbatti	man	vortice@gogolo.it	t	2005-08-03	it	Europe/Mariehamn	t
15	2014-04-28 08:09:01+00	{"0":{"project":true,"to":1,"to_project":"PROGETTO","datetime":"21:29","cmp":"1398626943","news":true},"1":{"from":18,"from_user":"kkklub","to":15,"to_user":"ges&ugrave;3","post_from_user":"ges&ugrave;3","post_from":15,"pid":2,"datetime":"19:54","cmp":"1398621281","board":false,"project":false},"2":{"project":true,"to":1,"to_project":"PROGETTO","datetime":"19:51","cmp":"1398621078","news":true},"3":{"from":17,"from_user":"Mgonad","to":14,"to_user":"mcelloni","post_from_user":"ges&ugrave;3","post_from":15,"pid":2,"datetime":"19:47","cmp":"1398620848","board":false,"project":false},"4":{"from":1,"from_user":"admin","to":3,"to_user":"mitchell","post_from_user":"ges&ugrave;3","post_from":15,"pid":3,"datetime":"19:32","cmp":"1398619923","board":false,"project":false},"5":{"from":2,"from_user":"PeppaPig","to":15,"to_user":"ges&ugrave;3","post_from_user":"ges&ugrave;3","post_from":15,"pid":2,"datetime":"16:48","cmp":"1398610103","board":false,"project":false},"6":{"from":2,"from_user":"PeppaPig","to":14,"to_user":"mcelloni","post_from_user":"ges&ugrave;3","post_from":15,"pid":2,"datetime":"ju\\u010der - 20:14","cmp":"1398536085","board":false,"project":false},"7":{"from":3,"from_user":"mitchell","to":3,"to_user":"mitchell","post_from_user":"ges&ugrave;3","post_from":15,"pid":3,"datetime":"ju\\u010der - 20:14","cmp":"1398536097","board":false,"project":false},"8":{"from":3,"from_user":"mitchell","to":15,"to_user":"ges&ugrave;3","post_from_user":"mcelloni","post_from":14,"pid":1,"datetime":"ju\\u010der - 20:16","cmp":"1398536175","board":false,"project":false},"9":{"from":3,"from_user":"mitchell","to":14,"to_user":"mcelloni","post_from_user":"ges&ugrave;3","post_from":15,"pid":2,"datetime":"ju\\u010der - 20:16","cmp":"1398536187","board":false,"project":false},"10":{"from":2,"from_user":"PeppaPig","to":15,"to_user":"ges&ugrave;3","post_from_user":"mcelloni","post_from":14,"pid":1,"datetime":"ju\\u010der - 20:17","cmp":"1398536253","board":false,"project":false},"11":{"from":14,"from_user":"mcelloni","to":"15","to_user":"ges&ugrave;3","pid":1,"datetime":"ju\\u010der - 20:15","cmp":"1398536119","board":true,"project":false}}	f	it	ges&ugrave;3	bf35c33b163d5ee02d7d4dd11110daf5da341988	daitarn	tre	anal@banana.com	t	2013-12-25	hr	Europe/Rome	t
8	2014-04-26 16:17:54+00	{"0":{"from":1,"from_user":"admin","to":8,"to_user":"L&#039;Altissimo Porco","post_from_user":"PeppaPig","post_from":2,"pid":2,"datetime":"17:14","cmp":"1398528881","board":false,"project":false},"1":{"from":2,"from_user":"PeppaPig","to":8,"to_user":"L&#039;Altissimo Porco","pid":2,"datetime":"17:14","cmp":"1398528864","board":true,"project":false},"2":{"from":1,"from_user":"admin","to":2,"to_user":"PeppaPig","post_from_user":"PeppaPig","post_from":2,"pid":3,"datetime":"17:13","cmp":"1398528800","board":false,"project":false},"3":{"from":1,"from_user":"admin","to":8,"to_user":"L&#039;Altissimo Porco","pid":1,"datetime":"17:12","cmp":"1398528767","board":true,"project":false}}	f	it	L&#039;Altissimo Porco	23de24af77f1d5c4fdacf90ae06cf0c10320709b	Altissimo	Ma un po&#039; porco	Highpig@safemail.info	t	1915-01-04	it	Africa/Brazzaville	t
11	2014-04-26 21:31:28+00	{"0":{"from":9,"from_user":"&lt;script&gt;alert(1)","to":11,"to_user":"owl","pid":3,"datetime":"18:37","cmp":"1398530279","board":true,"project":false},"1":{"from":2,"from_user":"PeppaPig","to":11,"to_user":"owl","post_from_user":"PeppaPig","post_from":2,"pid":2,"datetime":"18:30","cmp":"1398529830","board":false,"project":false},"2":{"from":2,"from_user":"PeppaPig","to":11,"to_user":"owl","post_from_user":"PeppaPig","post_from":2,"pid":2,"datetime":"18:28","cmp":"1398529718","board":false,"project":false},"3":{"from":2,"from_user":"PeppaPig","to":11,"to_user":"owl","pid":2,"datetime":"18:25","cmp":"1398529514","board":true,"project":false}}	f	it	owl	407ae5311c34cb8e20e0c7075553e99485135bed	owl	lamente	mattia@crazyup.org	t	1990-10-03	it	Europe/Rome	t
6	2014-04-27 17:38:26+00	{"0":{"from":1,"from_user":"admin","to":8,"to_user":"L&#039;Altissimo Porco","post_from_user":"PeppaPig","post_from":2,"pid":2,"datetime":"18:51","cmp":"1398531066","board":false,"project":false},"1":{"from":2,"from_user":"PeppaPig","to":11,"to_user":"owl","post_from_user":"PeppaPig","post_from":2,"pid":2,"datetime":"18:30","cmp":"1398529830","board":false,"project":false},"2":{"from":11,"from_user":"owl","to":11,"to_user":"owl","post_from_user":"PeppaPig","post_from":2,"pid":2,"datetime":"18:29","cmp":"1398529763","board":false,"project":false},"3":{"from":2,"from_user":"PeppaPig","to":11,"to_user":"owl","post_from_user":"PeppaPig","post_from":2,"pid":2,"datetime":"18:28","cmp":"1398529718","board":false,"project":false},"4":{"from":10,"from_user":"winter","to":10,"to_user":"winter","post_from_user":"winter","post_from":10,"pid":1,"datetime":"18:21","cmp":"1398529283","board":false,"project":false},"5":{"from":1,"from_user":"admin","to":2,"to_user":"PeppaPig","post_from_user":"PeppaPig","post_from":2,"pid":3,"datetime":"18:13","cmp":"1398528800","board":false,"project":false},"6":{"from":8,"from_user":"L&#039;Altissimo Porco","to":2,"to_user":"PeppaPig","post_from_user":"PeppaPig","post_from":2,"pid":3,"datetime":"18:12","cmp":"1398528758","board":false,"project":false},"7":{"from":1,"from_user":"admin","to":2,"to_user":"PeppaPig","post_from_user":"PeppaPig","post_from":2,"pid":3,"datetime":"18:12","cmp":"1398528748","board":false,"project":false},"8":{"from":2,"from_user":"PeppaPig","to":2,"to_user":"PeppaPig","post_from_user":"PeppaPig","post_from":2,"pid":3,"datetime":"18:11","cmp":"1398528706","board":false,"project":false},"9":{"from":1,"from_user":"admin","to":1,"to_user":"admin","post_from_user":"admin","post_from":1,"pid":13,"datetime":"18:09","cmp":"1398528577","board":false,"project":false},"10":{"from":1,"from_user":"admin","to":2,"to_user":"PeppaPig","post_from_user":"PeppaPig","post_from":2,"pid":3,"datetime":"18:09","cmp":"1398528558","board":false,"project":false},"11":{"from":2,"from_user":"PeppaPig","to":1,"to_user":"admin","post_from_user":"admin","post_from":1,"pid":13,"datetime":"18:09","cmp":"1398528547","board":false,"project":false},"12":{"from":2,"from_user":"PeppaPig","to":6,"to_user":"Doch88","post_from_user":"admin","post_from":1,"pid":3,"datetime":"18:03","cmp":"1398528238","board":false,"project":false},"13":{"from":1,"from_user":"admin","to":6,"to_user":"Doch88","post_from_user":"admin","post_from":1,"pid":3,"datetime":"18:03","cmp":"1398528233","board":false,"project":false},"14":{"from":1,"from_user":"admin","to":6,"to_user":"Doch88","post_from_user":"Doch88","post_from":6,"pid":2,"datetime":"18:03","cmp":"1398528207","board":false,"project":false},"15":{"from":1,"from_user":"admin","to":6,"to_user":"Doch88","pid":3,"datetime":"18:02","cmp":"1398528175","board":true,"project":false}}	t	it	Ananas	04522cc00084518436ffdbf295b45588c041b0da	Alberto	Giaccafredda	Doch_Davidoch@safetymail.info	t	2009-04-01	it	Europe/Rome	t
10	2014-04-27 22:09:22+00	{"0":{"follow":true,"from":6,"from_user":"Ananas","datetime":"16:31","cmp":"1398529861"},"1":{"from":2,"from_user":"PeppaPig","to":10,"to_user":"winter","post_from_user":"winter","post_from":10,"pid":1,"datetime":"16:19","cmp":"1398529197","board":false,"project":false}}	f	en	winter	25119c0fa481581bdd7cf5e19805bd72a0415bc6	winter	harris0n	alfateam123@hotmail.it	f	1970-01-01	en	Africa/Abidjan	t
12	2014-04-26 16:48:30+00	{"0":{"from":2,"from_user":"PeppaPig","to":12,"to_user":"Helium","post_from_user":"Helium","post_from":12,"pid":1,"datetime":"18:44","cmp":"1398530640","board":false,"project":false},"1":{"from":2,"from_user":"PeppaPig","to":12,"to_user":"Helium","post_from_user":"Helium","post_from":12,"pid":1,"datetime":"18:43","cmp":"1398530581","board":false,"project":false},"2":{"from":2,"from_user":"PeppaPig","to":12,"to_user":"Helium","post_from_user":"Helium","post_from":12,"pid":2,"datetime":"18:41","cmp":"1398530499","board":false,"project":false},"3":{"from":9,"from_user":"&lt;script&gt;alert(1)","to":12,"to_user":"Helium","post_from_user":"Helium","post_from":12,"pid":1,"datetime":"18:38","cmp":"1398530326","board":false,"project":false},"4":{"from":13,"from_user":"Albero Azzurro","to":12,"to_user":"Helium","post_from_user":"Helium","post_from":12,"pid":1,"datetime":"18:38","cmp":"1398530322","board":false,"project":false},"5":{"from":2,"from_user":"PeppaPig","to":12,"to_user":"Helium","post_from_user":"Helium","post_from":12,"pid":1,"datetime":"18:38","cmp":"1398530296","board":false,"project":false},"6":{"from":13,"from_user":"Albero Azzurro","to":12,"to_user":"Helium","post_from_user":"Helium","post_from":12,"pid":1,"datetime":"18:37","cmp":"1398530240","board":false,"project":false},"7":{"from":9,"from_user":"&lt;script&gt;alert(1)","to":12,"to_user":"Helium","post_from_user":"Helium","post_from":12,"pid":1,"datetime":"18:36","cmp":"1398530204","board":false,"project":false}}	f	en	Helium	55342b0fb9cf29e6d5a7649a2e02489344e49e32	Mel	Gibson	melgibson@mailinator.com	t	2009-01-09	en	Europe/Rome	t
13	2014-04-26 17:40:57+00	{"0":{"from":2,"from_user":"PeppaPig","to":2,"to_user":"PeppaPig","post_from_user":"Albero Azzurro","post_from":13,"pid":6,"datetime":"19:31","cmp":"1398533499","board":false,"project":false},"1":{"from":2,"from_user":"PeppaPig","to":2,"to_user":"PeppaPig","post_from_user":"Albero Azzurro","post_from":13,"pid":6,"datetime":"19:26","cmp":"1398533182","board":false,"project":false},"2":{"from":2,"from_user":"PeppaPig","to":2,"to_user":"PeppaPig","post_from_user":"Albero Azzurro","post_from":13,"pid":6,"datetime":"19:23","cmp":"1398532980","board":false,"project":false},"3":{"from":2,"from_user":"PeppaPig","to":2,"to_user":"PeppaPig","post_from_user":"Albero Azzurro","post_from":13,"pid":6,"datetime":"19:20","cmp":"1398532852","board":false,"project":false},"4":{"from":2,"from_user":"PeppaPig","to":2,"to_user":"PeppaPig","post_from_user":"Albero Azzurro","post_from":13,"pid":6,"datetime":"19:18","cmp":"1398532733","board":false,"project":false},"5":{"from":2,"from_user":"PeppaPig","to":2,"to_user":"PeppaPig","post_from_user":"Albero Azzurro","post_from":13,"pid":6,"datetime":"19:16","cmp":"1398532603","board":false,"project":false},"6":{"from":2,"from_user":"PeppaPig","to":13,"to_user":"Albero Azzurro","post_from_user":"PeppaPig","post_from":2,"pid":3,"datetime":"19:16","cmp":"1398532591","board":false,"project":false},"7":{"from":2,"from_user":"PeppaPig","to":13,"to_user":"Albero Azzurro","pid":3,"datetime":"19:16","cmp":"1398532575","board":true,"project":false},"8":{"from":2,"from_user":"PeppaPig","to":13,"to_user":"Albero Azzurro","post_from_user":"PeppaPig","post_from":2,"pid":3,"datetime":"19:16","cmp":"1398532581","board":false,"project":false},"9":{"from":2,"from_user":"PeppaPig","to":13,"to_user":"Albero Azzurro","post_from_user":"Albero Azzurro","post_from":13,"pid":2,"datetime":"19:15","cmp":"1398532548","board":false,"project":false},"10":{"from":2,"from_user":"PeppaPig","to":2,"to_user":"PeppaPig","post_from_user":"Albero Azzurro","post_from":13,"pid":6,"datetime":"19:14","cmp":"1398532490","board":false,"project":false},"11":{"from":2,"from_user":"PeppaPig","to":13,"to_user":"Albero Azzurro","post_from_user":"Albero Azzurro","post_from":13,"pid":2,"datetime":"19:12","cmp":"1398532377","board":false,"project":false},"12":{"from":2,"from_user":"PeppaPig","to":2,"to_user":"PeppaPig","post_from_user":"Albero Azzurro","post_from":13,"pid":6,"datetime":"19:11","cmp":"1398532319","board":false,"project":false},"13":{"from":2,"from_user":"PeppaPig","to":2,"to_user":"PeppaPig","post_from_user":"Albero Azzurro","post_from":13,"pid":6,"datetime":"19:04","cmp":"1398531845","board":false,"project":false},"14":{"from":2,"from_user":"PeppaPig","to":2,"to_user":"PeppaPig","post_from_user":"Albero Azzurro","post_from":13,"pid":6,"datetime":"19:02","cmp":"1398531742","board":false,"project":false},"15":{"from":2,"from_user":"PeppaPig","to":2,"to_user":"PeppaPig","post_from_user":"Albero Azzurro","post_from":13,"pid":6,"datetime":"18:54","cmp":"1398531260","board":false,"project":false}}	f	it	Albero Azzurro	4724d4f09255265cb76317a2201fa94d4447a1d7	Albero	Azzurro	AA@eldelc.ecec	t	2013-01-01	it	Africa/Cairo	t
\.


--
-- Name: users_counter_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('users_counter_seq', 20, true);


--
-- Data for Name: whitelist; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY whitelist ("from", "to") FROM stdin;
\.


--
-- Name: ban_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY ban
    ADD CONSTRAINT ban_pkey PRIMARY KEY ("user");


--
-- Name: blacklist_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY blacklist
    ADD CONSTRAINT blacklist_pkey PRIMARY KEY ("from", "to");


--
-- Name: bookmarks_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY bookmarks
    ADD CONSTRAINT bookmarks_pkey PRIMARY KEY ("from", hpid);


--
-- Name: closed_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY closed_profiles
    ADD CONSTRAINT closed_profiles_pkey PRIMARY KEY (counter);


--
-- Name: comment_thumbs_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY comment_thumbs
    ADD CONSTRAINT comment_thumbs_pkey PRIMARY KEY (hcid, "user");


--
-- Name: comments_no_notify_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY comments_no_notify
    ADD CONSTRAINT comments_no_notify_pkey PRIMARY KEY ("from", "to", hpid);


--
-- Name: comments_notify_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY comments_notify
    ADD CONSTRAINT comments_notify_pkey PRIMARY KEY ("from", "to", hpid);


--
-- Name: comments_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (hcid);


--
-- Name: groups_bookmarks_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_bookmarks
    ADD CONSTRAINT groups_bookmarks_pkey PRIMARY KEY ("from", hpid);


--
-- Name: groups_comment_thumbs_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_comment_thumbs
    ADD CONSTRAINT groups_comment_thumbs_pkey PRIMARY KEY (hcid, "user");


--
-- Name: groups_comments_no_notify_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_comments_no_notify
    ADD CONSTRAINT groups_comments_no_notify_pkey PRIMARY KEY ("from", "to", hpid);


--
-- Name: groups_comments_notify_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_comments_notify
    ADD CONSTRAINT groups_comments_notify_pkey PRIMARY KEY ("from", "to", hpid);


--
-- Name: groups_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_comments
    ADD CONSTRAINT groups_comments_pkey PRIMARY KEY (hcid);


--
-- Name: groups_followers_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_followers
    ADD CONSTRAINT groups_followers_pkey PRIMARY KEY ("group", "user");


--
-- Name: groups_lurkers_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_lurkers
    ADD CONSTRAINT groups_lurkers_pkey PRIMARY KEY ("user", post);


--
-- Name: groups_members_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_members
    ADD CONSTRAINT groups_members_pkey PRIMARY KEY ("group", "user");


--
-- Name: groups_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups
    ADD CONSTRAINT groups_pkey PRIMARY KEY (counter);


--
-- Name: groups_posts_no_notify_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_posts_no_notify
    ADD CONSTRAINT groups_posts_no_notify_pkey PRIMARY KEY ("user", hpid);


--
-- Name: groups_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_posts
    ADD CONSTRAINT groups_posts_pkey PRIMARY KEY (hpid);


--
-- Name: groups_thumbs_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_thumbs
    ADD CONSTRAINT groups_thumbs_pkey PRIMARY KEY (hpid, "user");


--
-- Name: lurkers_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY lurkers
    ADD CONSTRAINT lurkers_pkey PRIMARY KEY ("user", post);


--
-- Name: pms_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY pms
    ADD CONSTRAINT pms_pkey PRIMARY KEY (pmid);


--
-- Name: posts_no_notify_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY posts_no_notify
    ADD CONSTRAINT posts_no_notify_pkey PRIMARY KEY ("user", hpid);


--
-- Name: posts_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (hpid);


--
-- Name: profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (counter);


--
-- Name: thumbs_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY thumbs
    ADD CONSTRAINT thumbs_pkey PRIMARY KEY (hpid, "user");


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (counter);


--
-- Name: whitelist_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY whitelist
    ADD CONSTRAINT whitelist_pkey PRIMARY KEY ("from", "to");


--
-- Name: blacklistTo; Type: INDEX; Schema: public; Owner: test_db; Tablespace: 
--

CREATE INDEX "blacklistTo" ON blacklist USING btree ("to");


--
-- Name: cid; Type: INDEX; Schema: public; Owner: test_db; Tablespace: 
--

CREATE INDEX cid ON comments USING btree (hpid);


--
-- Name: commentsTo; Type: INDEX; Schema: public; Owner: test_db; Tablespace: 
--

CREATE INDEX "commentsTo" ON comments_notify USING btree ("to");


--
-- Name: fkdateformat; Type: INDEX; Schema: public; Owner: test_db; Tablespace: 
--

CREATE INDEX fkdateformat ON profiles USING btree (dateformat);


--
-- Name: followTo; Type: INDEX; Schema: public; Owner: test_db; Tablespace: 
--

CREATE INDEX "followTo" ON follow USING btree ("to", notified);


--
-- Name: gpid; Type: INDEX; Schema: public; Owner: test_db; Tablespace: 
--

CREATE INDEX gpid ON groups_posts USING btree (pid, "to");


--
-- Name: groupscid; Type: INDEX; Schema: public; Owner: test_db; Tablespace: 
--

CREATE INDEX groupscid ON groups_comments USING btree (hpid);


--
-- Name: groupsnto; Type: INDEX; Schema: public; Owner: test_db; Tablespace: 
--

CREATE INDEX groupsnto ON groups_notify USING btree ("to");


--
-- Name: pid; Type: INDEX; Schema: public; Owner: test_db; Tablespace: 
--

CREATE INDEX pid ON posts USING btree (pid, "to");


--
-- Name: whitelistTo; Type: INDEX; Schema: public; Owner: test_db; Tablespace: 
--

CREATE INDEX "whitelistTo" ON whitelist USING btree ("to");


--
-- Name: after_delete_blacklist; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER after_delete_blacklist AFTER DELETE ON blacklist FOR EACH ROW EXECUTE PROCEDURE after_delete_blacklist();


--
-- Name: before_delete_group; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER before_delete_group BEFORE DELETE ON groups FOR EACH ROW EXECUTE PROCEDURE before_delete_group();


--
-- Name: before_delete_groups_posts; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER before_delete_groups_posts BEFORE DELETE ON groups_posts FOR EACH ROW EXECUTE PROCEDURE before_delete_groups_posts();


--
-- Name: before_delete_post; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER before_delete_post BEFORE DELETE ON posts FOR EACH ROW EXECUTE PROCEDURE before_delete_post();


--
-- Name: before_delete_user; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER before_delete_user BEFORE DELETE ON users FOR EACH ROW EXECUTE PROCEDURE before_delete_user();


--
-- Name: before_insert_blacklist; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER before_insert_blacklist BEFORE INSERT ON blacklist FOR EACH ROW EXECUTE PROCEDURE before_insert_blacklist();


--
-- Name: before_insert_on_groups_lurkers; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER before_insert_on_groups_lurkers BEFORE INSERT ON groups_lurkers FOR EACH ROW EXECUTE PROCEDURE before_insert_on_groups_lurkers();


--
-- Name: before_insert_on_lurkers; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER before_insert_on_lurkers BEFORE INSERT ON lurkers FOR EACH ROW EXECUTE PROCEDURE before_insert_on_lurkers();


--
-- Name: destfkusers; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY posts_no_notify
    ADD CONSTRAINT destfkusers FOREIGN KEY ("user") REFERENCES users(counter);


--
-- Name: destgrofkusers; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_posts_no_notify
    ADD CONSTRAINT destgrofkusers FOREIGN KEY ("user") REFERENCES users(counter);


--
-- Name: fkbanned; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY ban
    ADD CONSTRAINT fkbanned FOREIGN KEY ("user") REFERENCES users(counter);


--
-- Name: fkfromfol; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY follow
    ADD CONSTRAINT fkfromfol FOREIGN KEY ("from") REFERENCES users(counter);


--
-- Name: fkfromnonot; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_comments_notify
    ADD CONSTRAINT fkfromnonot FOREIGN KEY ("from") REFERENCES users(counter);


--
-- Name: fkfromnonotproj; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_comments_notify
    ADD CONSTRAINT fkfromnonotproj FOREIGN KEY ("to") REFERENCES users(counter);


--
-- Name: fkfromproj; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_posts
    ADD CONSTRAINT fkfromproj FOREIGN KEY ("from") REFERENCES users(counter);


--
-- Name: fkfromprojnonot; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_comments_no_notify
    ADD CONSTRAINT fkfromprojnonot FOREIGN KEY ("from") REFERENCES users(counter);


--
-- Name: fkfromusers; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY blacklist
    ADD CONSTRAINT fkfromusers FOREIGN KEY ("from") REFERENCES users(counter);


--
-- Name: fkfromusersp; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_comments
    ADD CONSTRAINT fkfromusersp FOREIGN KEY ("from") REFERENCES users(counter);


--
-- Name: fkfromuserswl; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY whitelist
    ADD CONSTRAINT fkfromuserswl FOREIGN KEY ("from") REFERENCES users(counter);


--
-- Name: fkowner; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups
    ADD CONSTRAINT fkowner FOREIGN KEY (owner) REFERENCES users(counter);


--
-- Name: fktofol; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY follow
    ADD CONSTRAINT fktofol FOREIGN KEY ("to") REFERENCES users(counter);


--
-- Name: fktoproj; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_posts
    ADD CONSTRAINT fktoproj FOREIGN KEY ("to") REFERENCES groups(counter);


--
-- Name: fktoproject; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_comments
    ADD CONSTRAINT fktoproject FOREIGN KEY ("to") REFERENCES groups(counter);


--
-- Name: fktoprojnonot; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_comments_no_notify
    ADD CONSTRAINT fktoprojnonot FOREIGN KEY ("to") REFERENCES users(counter);


--
-- Name: fktousers; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY blacklist
    ADD CONSTRAINT fktousers FOREIGN KEY ("to") REFERENCES users(counter);


--
-- Name: fktouserswl; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY whitelist
    ADD CONSTRAINT fktouserswl FOREIGN KEY ("to") REFERENCES users(counter);


--
-- Name: fkuser; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY closed_profiles
    ADD CONSTRAINT fkuser FOREIGN KEY (counter) REFERENCES users(counter);


--
-- Name: foregngrouphpid; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_posts_no_notify
    ADD CONSTRAINT foregngrouphpid FOREIGN KEY (hpid) REFERENCES groups_posts(hpid);


--
-- Name: foreignfromusers; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY comments
    ADD CONSTRAINT foreignfromusers FOREIGN KEY ("from") REFERENCES users(counter);


--
-- Name: foreignhpid; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY posts_no_notify
    ADD CONSTRAINT foreignhpid FOREIGN KEY (hpid) REFERENCES posts(hpid);


--
-- Name: foreignhpid; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY comments_notify
    ADD CONSTRAINT foreignhpid FOREIGN KEY (hpid) REFERENCES posts(hpid);


--
-- Name: foreignkfromusers; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY posts
    ADD CONSTRAINT foreignkfromusers FOREIGN KEY ("from") REFERENCES users(counter);


--
-- Name: foreignktousers; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY posts
    ADD CONSTRAINT foreignktousers FOREIGN KEY ("to") REFERENCES users(counter);


--
-- Name: foreigntousers; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY comments
    ADD CONSTRAINT foreigntousers FOREIGN KEY ("to") REFERENCES users(counter);


--
-- Name: forhpid; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY comments_no_notify
    ADD CONSTRAINT forhpid FOREIGN KEY (hpid) REFERENCES posts(hpid);


--
-- Name: forhpidbm; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY bookmarks
    ADD CONSTRAINT forhpidbm FOREIGN KEY (hpid) REFERENCES posts(hpid);


--
-- Name: forhpidbmgr; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_bookmarks
    ADD CONSTRAINT forhpidbmgr FOREIGN KEY (hpid) REFERENCES groups_posts(hpid);


--
-- Name: forkeyfromusers; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY comments_no_notify
    ADD CONSTRAINT forkeyfromusers FOREIGN KEY ("from") REFERENCES users(counter);


--
-- Name: forkeyfromusersbmarks; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY bookmarks
    ADD CONSTRAINT forkeyfromusersbmarks FOREIGN KEY ("from") REFERENCES users(counter);


--
-- Name: forkeyfromusersgrbmarks; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_bookmarks
    ADD CONSTRAINT forkeyfromusersgrbmarks FOREIGN KEY ("from") REFERENCES users(counter);


--
-- Name: forkeytousers; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY comments_no_notify
    ADD CONSTRAINT forkeytousers FOREIGN KEY ("to") REFERENCES users(counter);


--
-- Name: fornotfkeyfromusers; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY comments_notify
    ADD CONSTRAINT fornotfkeyfromusers FOREIGN KEY ("from") REFERENCES users(counter);


--
-- Name: fornotfkeytousers; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY comments_notify
    ADD CONSTRAINT fornotfkeytousers FOREIGN KEY ("to") REFERENCES users(counter);


--
-- Name: fromrefus; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY pms
    ADD CONSTRAINT fromrefus FOREIGN KEY ("from") REFERENCES users(counter);


--
-- Name: grforkey; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_notify
    ADD CONSTRAINT grforkey FOREIGN KEY ("group") REFERENCES groups(counter);


--
-- Name: groupfkg; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_members
    ADD CONSTRAINT groupfkg FOREIGN KEY ("group") REFERENCES groups(counter);


--
-- Name: groupfollofkg; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_followers
    ADD CONSTRAINT groupfollofkg FOREIGN KEY ("group") REFERENCES groups(counter);


--
-- Name: hcidgthumbs; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_comment_thumbs
    ADD CONSTRAINT hcidgthumbs FOREIGN KEY (hcid) REFERENCES groups_comments(hcid) ON DELETE CASCADE;


--
-- Name: hcidthumbs; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY comment_thumbs
    ADD CONSTRAINT hcidthumbs FOREIGN KEY (hcid) REFERENCES comments(hcid) ON DELETE CASCADE;


--
-- Name: hpidgthumbs; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_thumbs
    ADD CONSTRAINT hpidgthumbs FOREIGN KEY (hpid) REFERENCES groups_posts(hpid) ON DELETE CASCADE;


--
-- Name: hpidproj; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_comments
    ADD CONSTRAINT hpidproj FOREIGN KEY (hpid) REFERENCES groups_posts(hpid);


--
-- Name: hpidprojnonot; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_comments_no_notify
    ADD CONSTRAINT hpidprojnonot FOREIGN KEY (hpid) REFERENCES groups_posts(hpid);


--
-- Name: hpidref; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY comments
    ADD CONSTRAINT hpidref FOREIGN KEY (hpid) REFERENCES posts(hpid);


--
-- Name: hpidthumbs; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY thumbs
    ADD CONSTRAINT hpidthumbs FOREIGN KEY (hpid) REFERENCES posts(hpid) ON DELETE CASCADE;


--
-- Name: refhipdgl; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_lurkers
    ADD CONSTRAINT refhipdgl FOREIGN KEY (post) REFERENCES groups_posts(hpid);


--
-- Name: refhipdl; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY lurkers
    ADD CONSTRAINT refhipdl FOREIGN KEY (post) REFERENCES posts(hpid);


--
-- Name: reftogroupshpid; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_comments_notify
    ADD CONSTRAINT reftogroupshpid FOREIGN KEY (hpid) REFERENCES groups_posts(hpid);


--
-- Name: refusergl; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_lurkers
    ADD CONSTRAINT refusergl FOREIGN KEY ("user") REFERENCES users(counter);


--
-- Name: refuserl; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY lurkers
    ADD CONSTRAINT refuserl FOREIGN KEY ("user") REFERENCES users(counter);


--
-- Name: torefus; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY pms
    ADD CONSTRAINT torefus FOREIGN KEY ("to") REFERENCES users(counter);


--
-- Name: userfkg; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_members
    ADD CONSTRAINT userfkg FOREIGN KEY ("user") REFERENCES users(counter);


--
-- Name: userfollofkg; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_followers
    ADD CONSTRAINT userfollofkg FOREIGN KEY ("user") REFERENCES users(counter);


--
-- Name: usergthumbs; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_thumbs
    ADD CONSTRAINT usergthumbs FOREIGN KEY ("user") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: usergthumbs; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_comment_thumbs
    ADD CONSTRAINT usergthumbs FOREIGN KEY ("user") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: userthumbs; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY thumbs
    ADD CONSTRAINT userthumbs FOREIGN KEY ("user") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: userthumbs; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY comment_thumbs
    ADD CONSTRAINT userthumbs FOREIGN KEY ("user") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: usetoforkey; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_notify
    ADD CONSTRAINT usetoforkey FOREIGN KEY ("to") REFERENCES users(counter);


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

