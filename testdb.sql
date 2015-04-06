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
-- Name: after_delete_user(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION after_delete_user() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    insert into deleted_users(counter, username) values(OLD.counter, OLD.username);
    RETURN NULL;
    -- if the user gives a motivation, the upper level might update this row
end $$;


ALTER FUNCTION public.after_delete_user() OWNER TO test_db;

--
-- Name: after_insert_blacklist(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION after_insert_blacklist() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE r RECORD;
BEGIN
    INSERT INTO posts_no_notify("user","hpid")
    (
        SELECT NEW."from", "hpid" FROM "posts" WHERE "to" = NEW."to" OR "from" = NEW."to" -- posts made by the blacklisted user and post on his board
            UNION DISTINCT
        SELECT NEW."from", "hpid" FROM "comments" WHERE "from" = NEW."to" OR "to" = NEW."to" -- comments made by blacklisted user on others and his board
    )
    EXCEPT -- except existing ones
    (
        SELECT NEW."from", "hpid" FROM "posts_no_notify" WHERE "user" = NEW."from"
    );

    INSERT INTO groups_posts_no_notify("user","hpid")
    (
        (
            SELECT NEW."from", "hpid" FROM "groups_posts" WHERE "from" = NEW."to" -- posts made by the blacklisted user in every project
                UNION DISTINCT
            SELECT NEW."from", "hpid" FROM "groups_comments" WHERE "from" = NEW."to" -- comments made by the blacklisted user in every project
        )
        EXCEPT -- except existing ones
        (
            SELECT NEW."from", "hpid" FROM "groups_posts_no_notify" WHERE "user" = NEW."from"
        )
    );
    

    FOR r IN (SELECT "to" FROM "groups_owners" WHERE "from" = NEW."from")
    LOOP
        -- remove from my groups members
        DELETE FROM "groups_members" WHERE "from" = NEW."to" AND "to" = r."to";
    END LOOP;
    
    -- remove from followers
    DELETE FROM "followers" WHERE ("from" = NEW."from" AND "to" = NEW."to");

    -- remove pms
    DELETE FROM "pms" WHERE ("from" = NEW."from" AND "to" = NEW."to") OR ("to" = NEW."from" AND "from" = NEW."to");

    -- remove from mentions
    DELETE FROM "mentions" WHERE ("from"= NEW."from" AND "to" = NEW."to") OR ("to" = NEW."from" AND "from" = NEW."to");

    RETURN NULL;
END $$;


ALTER FUNCTION public.after_insert_blacklist() OWNER TO test_db;

--
-- Name: after_insert_group_post(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION after_insert_group_post() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    WITH to_notify("user") AS (
        (
            -- members
            SELECT "from" FROM "groups_members" WHERE "to" = NEW."to"
                UNION DISTINCT
            --followers
            SELECT "from" FROM "groups_followers" WHERE "to" = NEW."to"
                UNION DISTINCT
            SELECT "from"  FROM "groups_owners" WHERE "to" = NEW."to"
        )
        EXCEPT
        (
            -- blacklist
            SELECT "from" AS "user" FROM "blacklist" WHERE "to" = NEW."from"
                UNION DISTINCT
            SELECT "to" AS "user" FROM "blacklist" WHERE "from" = NEW."from"
                UNION DISTINCT
            SELECT NEW."from" -- I shouldn't be notified about my new post
        )
    )

    INSERT INTO "groups_notify"("from", "to", "time", "hpid") (
        SELECT NEW."to", "user", NEW."time", NEW."hpid" FROM to_notify
    );

    PERFORM hashtag(NEW.message, NEW.hpid, true);
    PERFORM mention(NEW."from", NEW.message, NEW.hpid, true);
    RETURN NULL;
END $$;


ALTER FUNCTION public.after_insert_group_post() OWNER TO test_db;

--
-- Name: after_insert_user(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION after_insert_user() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
        INSERT INTO "profiles"(counter) VALUES(NEW.counter);
        RETURN NULL;
    END $$;


ALTER FUNCTION public.after_insert_user() OWNER TO test_db;

--
-- Name: after_insert_user_post(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION after_insert_user_post() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
    IF NEW."from" <> NEW."to" THEN
        insert into posts_notify("from", "to", "hpid", "time") values(NEW."from", NEW."to", NEW."hpid", NEW."time");
    END IF;
    PERFORM hashtag(NEW.message, NEW.hpid, false);
    PERFORM mention(NEW."from", NEW.message, NEW.hpid, false);
    return null;
end $$;


ALTER FUNCTION public.after_insert_user_post() OWNER TO test_db;

--
-- Name: after_update_userame(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION after_update_userame() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- create news
    insert into posts("from","to","message")
    SELECT counter, counter,
    OLD.username || ' %%12now is34%% [user]' || NEW.username || '[/user]' FROM special_users WHERE "role" = 'GLOBAL_NEWS';

    RETURN NULL;
END $$;


ALTER FUNCTION public.after_update_userame() OWNER TO test_db;

--
-- Name: before_delete_user(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION before_delete_user() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
        UPDATE "comments" SET "from" = (SELECT "counter" FROM "special_users" WHERE "role" = 'DELETED') WHERE "from" = OLD.counter;
        UPDATE "posts" SET "from" = (SELECT "counter" FROM "special_users" WHERE "role" = 'DELETED') WHERE "from" = OLD.counter;

        UPDATE "groups_comments" SET "from" = (SELECT "counter" FROM "special_users" WHERE "role" = 'DELETED') WHERE "from" = OLD.counter;            
        UPDATE "groups_posts" SET "from" = (SELECT "counter" FROM "special_users" WHERE "role" = 'DELETED') WHERE "from" = OLD.counter;

        PERFORM handle_groups_on_user_delete(OLD.counter);

        RETURN OLD;
    END
$$;


ALTER FUNCTION public.before_delete_user() OWNER TO test_db;

--
-- Name: before_insert_comment(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION before_insert_comment() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE closedPost boolean;
BEGIN
    PERFORM flood_control('"comments"', NEW."from", NEW.message);
    SELECT closed FROM posts INTO closedPost WHERE hpid = NEW.hpid;
    IF closedPost THEN
        RAISE EXCEPTION 'CLOSED_POST';
    END IF;

    SELECT p."to" INTO NEW."to" FROM "posts" p WHERE p.hpid = NEW.hpid;
    PERFORM blacklist_control(NEW."from", NEW."to");

    NEW.message = message_control(NEW.message);

    RETURN NEW;
END $$;


ALTER FUNCTION public.before_insert_comment() OWNER TO test_db;

--
-- Name: before_insert_comment_thumb(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION before_insert_comment_thumb() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE postFrom int8;
        tmp record;
BEGIN
    PERFORM flood_control('"comment_thumbs"', NEW."from");

    SELECT T."to", T."from", T."hpid" INTO tmp FROM (SELECT "from", "to", "hpid" FROM "comments" WHERE "hcid" = NEW.hcid) AS T;
    SELECT tmp."from" INTO NEW."to";

    PERFORM blacklist_control(NEW."from", NEW."to"); --blacklisted commenter

    SELECT T."from", T."to" INTO tmp FROM (SELECT p."from", p."to" FROM "posts" p WHERE p.hpid = tmp.hpid) AS T;

    PERFORM blacklist_control(NEW."from", tmp."from"); --blacklisted post creator
    IF tmp."from" <> tmp."to" THEN
        PERFORM blacklist_control(NEW."from", tmp."to"); --blacklisted post destination user
    END IF;

    IF NEW."vote" = 0 THEN
        DELETE FROM "comment_thumbs" WHERE hcid = NEW.hcid AND "from" = NEW."from";
        RETURN NULL;
    END IF;
    
    WITH new_values (hcid, "from", vote) AS (
            VALUES(NEW."hcid", NEW."from", NEW."vote")
        ),
        upsert AS (
            UPDATE "comment_thumbs" AS m
            SET vote = nv.vote
            FROM new_values AS nv
            WHERE m.hcid = nv.hcid AND m."from" = nv."from"
            RETURNING m.*
       )

       SELECT "vote" INTO NEW."vote"
       FROM new_values
       WHERE NOT EXISTS (
           SELECT 1
           FROM upsert AS up
           WHERE up.hcid = new_values.hcid AND up."from" = new_values."from"
      );

    IF NEW."vote" IS NULL THEN -- updated previous vote
        RETURN NULL; --no need to insert new value
    END IF;
    
    RETURN NEW;
END $$;


ALTER FUNCTION public.before_insert_comment_thumb() OWNER TO test_db;

--
-- Name: before_insert_follower(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION before_insert_follower() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM flood_control('"followers"', NEW."from");
    IF NEW."from" = NEW."to" THEN
        RAISE EXCEPTION 'CANT_FOLLOW_YOURSELF';
    END IF;
    PERFORM blacklist_control(NEW."from", NEW."to");
    RETURN NEW;
END $$;


ALTER FUNCTION public.before_insert_follower() OWNER TO test_db;

--
-- Name: before_insert_group_post_lurker(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION before_insert_group_post_lurker() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE tmp RECORD;
BEGIN
    PERFORM flood_control('"groups_lurkers"', NEW."from");

    SELECT T."to", T."from" INTO tmp FROM (SELECT "to", "from" FROM "groups_posts" WHERE "hpid" = NEW.hpid) AS T;

    SELECT tmp."to" INTO NEW."to";

    PERFORM blacklist_control(NEW."from", tmp."from"); --blacklisted post creator

    IF NEW."from" IN ( SELECT "from" FROM "groups_comments" WHERE hpid = NEW.hpid ) THEN
        RAISE EXCEPTION 'CANT_LURK_IF_POSTED';
    END IF;
    
    RETURN NEW;
END $$;


ALTER FUNCTION public.before_insert_group_post_lurker() OWNER TO test_db;

--
-- Name: before_insert_groups_comment(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION before_insert_groups_comment() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE postFrom int8;
        closedPost boolean;
BEGIN
    PERFORM flood_control('"groups_comments"', NEW."from", NEW.message);

    SELECT closed FROM groups_posts INTO closedPost WHERE hpid = NEW.hpid;
    IF closedPost THEN
        RAISE EXCEPTION 'CLOSED_POST';
    END IF;

    SELECT p."to" INTO NEW."to" FROM "groups_posts" p WHERE p.hpid = NEW.hpid;

    NEW.message = message_control(NEW.message);


    SELECT T."from" INTO postFrom FROM (SELECT "from" FROM "groups_posts" WHERE hpid = NEW.hpid) AS T;
    PERFORM blacklist_control(NEW."from", postFrom); --blacklisted post creator

    RETURN NEW;
END $$;


ALTER FUNCTION public.before_insert_groups_comment() OWNER TO test_db;

--
-- Name: before_insert_groups_comment_thumb(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION before_insert_groups_comment_thumb() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE tmp record;
        postFrom int8;
BEGIN
    PERFORM flood_control('"groups_comment_thumbs"', NEW."from");

    SELECT T."hpid", T."from", T."to" INTO tmp FROM (SELECT "hpid", "from","to" FROM "groups_comments" WHERE "hcid" = NEW.hcid) AS T;
    SELECT tmp."from" INTO NEW."to";

    PERFORM blacklist_control(NEW."from", NEW."to"); --blacklisted commenter

    SELECT T."from" INTO postFrom FROM (SELECT p."from" FROM "groups_posts" p WHERE p.hpid = tmp.hpid) AS T;

    PERFORM blacklist_control(NEW."from", postFrom); --blacklisted post creator

    IF NEW."vote" = 0 THEN
        DELETE FROM "groups_comment_thumbs" WHERE hcid = NEW.hcid AND "from" = NEW."from";
        RETURN NULL;
    END IF;

    WITH new_values (hcid, "from", vote) AS (
            VALUES(NEW."hcid", NEW."from", NEW."vote")
        ),
        upsert AS (
            UPDATE "groups_comment_thumbs" AS m
            SET vote = nv.vote
            FROM new_values AS nv
            WHERE m.hcid = nv.hcid AND m."from" = nv."from"
            RETURNING m.*
       )

       SELECT "vote" INTO NEW."vote"
       FROM new_values
       WHERE NOT EXISTS (
           SELECT 1
           FROM upsert AS up
           WHERE up.hcid = new_values.hcid AND up."from" = new_values."from"
      );

    IF NEW."vote" IS NULL THEN -- updated previous vote
        RETURN NULL; --no need to insert new value
    END IF;
    
    RETURN NEW;
END $$;


ALTER FUNCTION public.before_insert_groups_comment_thumb() OWNER TO test_db;

--
-- Name: before_insert_groups_follower(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION before_insert_groups_follower() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE group_owner int8;
BEGIN
    PERFORM flood_control('"groups_followers"', NEW."from");
    SELECT "from" INTO group_owner FROM "groups_owners" WHERE "to" = NEW."to";
    PERFORM blacklist_control(group_owner, NEW."from");
    RETURN NEW;
END $$;


ALTER FUNCTION public.before_insert_groups_follower() OWNER TO test_db;

--
-- Name: before_insert_groups_member(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION before_insert_groups_member() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE group_owner int8;
BEGIN
    SELECT "from" INTO group_owner FROM "groups_owners" WHERE "to" = NEW."to";
    PERFORM blacklist_control(group_owner, NEW."from");
    RETURN NEW;
END $$;


ALTER FUNCTION public.before_insert_groups_member() OWNER TO test_db;

--
-- Name: before_insert_groups_thumb(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION before_insert_groups_thumb() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE  tmp record;
BEGIN
    PERFORM flood_control('"groups_thumbs"', NEW."from");

    SELECT T."to", T."from" INTO tmp
    FROM (SELECT "to", "from" FROM "groups_posts" WHERE "hpid" = NEW.hpid) AS T;

    SELECT tmp."from" INTO NEW."to";

    PERFORM blacklist_control(NEW."from", NEW."to"); -- blacklisted post creator

    IF NEW."vote" = 0 THEN
        DELETE FROM "groups_thumbs" WHERE hpid = NEW.hpid AND "from" = NEW."from";
        RETURN NULL;
    END IF;

    WITH new_values (hpid, "from", vote) AS (
            VALUES(NEW."hpid", NEW."from", NEW."vote")
        ),
        upsert AS (
            UPDATE "groups_thumbs" AS m
            SET vote = nv.vote
            FROM new_values AS nv
            WHERE m.hpid = nv.hpid AND m."from" = nv."from"
            RETURNING m.*
       )

       SELECT "vote" INTO NEW."vote"
       FROM new_values
       WHERE NOT EXISTS (
           SELECT 1
           FROM upsert AS up
           WHERE up.hpid = new_values.hpid AND up."from" = new_values."from"
      );

    IF NEW."vote" IS NULL THEN -- updated previous vote
        RETURN NULL; --no need to insert new value
    END IF;
    
    RETURN NEW;
END $$;


ALTER FUNCTION public.before_insert_groups_thumb() OWNER TO test_db;

--
-- Name: before_insert_pm(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION before_insert_pm() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE myLastMessage RECORD;
BEGIN
    NEW.message = message_control(NEW.message);
    PERFORM flood_control('"pms"', NEW."from", NEW.message);

    IF NEW."from" = NEW."to" THEN
        RAISE EXCEPTION 'CANT_PM_YOURSELF';
    END IF;

    PERFORM blacklist_control(NEW."from", NEW."to");
    RETURN NEW;
END $$;


ALTER FUNCTION public.before_insert_pm() OWNER TO test_db;

--
-- Name: before_insert_thumb(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION before_insert_thumb() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE tmp RECORD;
BEGIN
    PERFORM flood_control('"thumbs"', NEW."from");

    SELECT T."to", T."from" INTO tmp FROM (SELECT "to", "from" FROM "posts" WHERE "hpid" = NEW.hpid) AS T;

    SELECT tmp."to" INTO NEW."to";

    PERFORM blacklist_control(NEW."from", NEW."to"); -- can't thumb on blacklisted board
    IF tmp."from" <> tmp."to" THEN
        PERFORM blacklist_control(NEW."from", tmp."from"); -- can't thumbs if post was made by blacklisted user
    END IF;

    IF NEW."vote" = 0 THEN
        DELETE FROM "thumbs" WHERE hpid = NEW.hpid AND "from" = NEW."from";
        RETURN NULL;
    END IF;
   
    WITH new_values (hpid, "from", vote) AS (
            VALUES(NEW."hpid", NEW."from", NEW."vote")
        ),
        upsert AS (
            UPDATE "thumbs" AS m
            SET vote = nv.vote
            FROM new_values AS nv
            WHERE m.hpid = nv.hpid AND m."from" = nv."from"
            RETURNING m.*
       )

       SELECT "vote" INTO NEW."vote"
       FROM new_values
       WHERE NOT EXISTS (
           SELECT 1
           FROM upsert AS up
           WHERE up.hpid = new_values.hpid AND up."from" = new_values."from"
      );

    IF NEW."vote" IS NULL THEN -- updated previous vote
        RETURN NULL; --no need to insert new value
    END IF;
    
    RETURN NEW;
END $$;


ALTER FUNCTION public.before_insert_thumb() OWNER TO test_db;

--
-- Name: before_insert_user_post_lurker(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION before_insert_user_post_lurker() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE tmp RECORD;
BEGIN
    PERFORM flood_control('"lurkers"', NEW."from");

    SELECT T."to", T."from" INTO tmp FROM (SELECT "to", "from" FROM "posts" WHERE "hpid" = NEW.hpid) AS T;

    SELECT tmp."to" INTO NEW."to";

    PERFORM blacklist_control(NEW."from", NEW."to"); -- can't lurk on blacklisted board
    IF tmp."from" <> tmp."to" THEN
        PERFORM blacklist_control(NEW."from", tmp."from"); -- can't lurk if post was made by blacklisted user
    END IF;

    IF NEW."from" IN ( SELECT "from" FROM "comments" WHERE hpid = NEW.hpid ) THEN
        RAISE EXCEPTION 'CANT_LURK_IF_POSTED';
    END IF;
    
    RETURN NEW;
    
END $$;


ALTER FUNCTION public.before_insert_user_post_lurker() OWNER TO test_db;

--
-- Name: blacklist_control(bigint, bigint); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION blacklist_control(me bigint, other bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- templates and other implementations must handle exceptions with localized functions
    IF me IN (SELECT "from" FROM blacklist WHERE "to" = other) THEN
        RAISE EXCEPTION 'YOU_BLACKLISTED_THIS_USER';
    END IF;

    IF me IN (SELECT "to" FROM blacklist WHERE "from" = other) THEN
        RAISE EXCEPTION 'YOU_HAVE_BEEN_BLACKLISTED';
    END IF;
END $$;


ALTER FUNCTION public.blacklist_control(me bigint, other bigint) OWNER TO test_db;

--
-- Name: flood_control(regclass, bigint, text); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION flood_control(tbl regclass, flooder bigint, message text DEFAULT NULL::text) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE now timestamp(0) with time zone;
        lastAction timestamp(0) with time zone;
        interv interval minute to second;
        myLastMessage text;
        postId text;
BEGIN
    EXECUTE 'SELECT MAX("time") FROM ' || tbl || ' WHERE "from" = ' || flooder || ';' INTO lastAction;
    now := NOW();

    SELECT time FROM flood_limits WHERE table_name = tbl INTO interv;

    IF now - lastAction < interv THEN
        RAISE EXCEPTION 'FLOOD ~%~', interv - (now - lastAction);
    END IF;

    -- duplicate messagee
    IF message IS NOT NULL AND tbl IN ('comments', 'groups_comments', 'posts', 'groups_posts') THEN
        
        SELECT CASE
           WHEN tbl IN ('comments', 'groups_comments') THEN 'hcid'
           WHEN tbl IN ('posts', 'groups_posts') THEN 'hpid'
           ELSE 'pmid'
        END AS columnName INTO postId;

        EXECUTE 'SELECT "message" FROM ' || tbl || ' WHERE "from" = ' || flooder || ' AND ' || postId || ' = (
            SELECT MAX(' || postId ||') FROM ' || tbl || ' WHERE "from" = ' || flooder || ')' INTO myLastMessage;

        IF myLastMessage = message THEN
            RAISE EXCEPTION 'FLOOD';
        END IF;
    END IF;
END $$;


ALTER FUNCTION public.flood_control(tbl regclass, flooder bigint, message text) OWNER TO test_db;

--
-- Name: group_comment(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION group_comment() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM hashtag(NEW.message, NEW.hpid, true);
    PERFORM mention(NEW."from", NEW.message, NEW.hpid, true);
    -- edit support
    IF TG_OP = 'UPDATE' THEN
        INSERT INTO groups_comments_revisions(hcid, time, message, rev_no)
        VALUES(OLD.hcid, OLD.time, OLD.message, (
            SELECT COUNT(hcid) + 1 FROM groups_comments_revisions WHERE hcid = OLD.hcid
        ));

         --notify only if it's the last comment in the post
        IF OLD.hcid <> (SELECT MAX(hcid) FROM groups_comments WHERE hpid = NEW.hpid) THEN
            RETURN NULL;
        END IF;
    END IF;


    -- if I commented the post, I stop lurking
    DELETE FROM "groups_lurkers" WHERE "hpid" = NEW."hpid" AND "from" = NEW."from";

    WITH no_notify("user") AS (
        -- blacklist
        (
            SELECT "from" FROM "blacklist" WHERE "to" = NEW."from"
                UNION
            SELECT "to" FROM "blacklist" WHERE "from" = NEW."from"
        )
        UNION -- users that locked the notifications for all the thread
            SELECT "user" FROM "groups_posts_no_notify" WHERE "hpid" = NEW."hpid"
        UNION -- users that locked notifications from me in this thread
            SELECT "to" FROM "groups_comments_no_notify" WHERE "from" = NEW."from" AND "hpid" = NEW."hpid"
        UNION -- users mentioned in this post (already notified, with the mention)
            SELECT "to" FROM "mentions" WHERE "g_hpid" = NEW.hpid AND to_notify IS TRUE
        UNION
            SELECT NEW."from"
    ),
    to_notify("user") AS (
            SELECT DISTINCT "from" FROM "groups_comments" WHERE "hpid" = NEW."hpid"
        UNION
            SELECT "from" FROM "groups_lurkers" WHERE "hpid" = NEW."hpid"
        UNION
            SELECT "from" FROM "groups_posts" WHERE "hpid" = NEW."hpid"
    ),
    real_notify("user") AS (
        -- avoid to add rows with the same primary key
        SELECT "user" FROM (
            SELECT "user" FROM to_notify
                EXCEPT
            (
                SELECT "user" FROM no_notify
             UNION
                SELECT "to" FROM "groups_comments_notify" WHERE "hpid" = NEW."hpid"
            )
        ) AS T1
    )

    INSERT INTO "groups_comments_notify"("from","to","hpid","time") (
        SELECT NEW."from", "user", NEW."hpid", NEW."time" FROM real_notify
    );

    RETURN NULL;
END $$;


ALTER FUNCTION public.group_comment() OWNER TO test_db;

--
-- Name: group_comment_edit_control(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION group_comment_edit_control() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE postFrom int8;
BEGIN
    IF OLD.editable IS FALSE THEN
        RAISE EXCEPTION 'NOT_EDITABLE';
    END IF;

    -- update time
    SELECT NOW() INTO NEW.time;

    NEW.message = message_control(NEW.message);
    PERFORM flood_control('"groups_comments"', NEW."from", NEW.message);

    SELECT T."from" INTO postFrom FROM (SELECT "from" FROM "groups_posts" WHERE hpid = NEW.hpid) AS T;
    PERFORM blacklist_control(NEW."from", postFrom); --blacklisted post creator

    RETURN NEW;
END $$;


ALTER FUNCTION public.group_comment_edit_control() OWNER TO test_db;

--
-- Name: group_interactions(bigint, bigint); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION group_interactions(me bigint, grp bigint) RETURNS SETOF record
    LANGUAGE plpgsql
    AS $$
DECLARE tbl text;
        ret record;
        query text;
BEGIN
    FOR tbl IN (SELECT unnest(array['groups_members', 'groups_followers', 'groups_comments', 'groups_comment_thumbs', 'groups_lurkers', 'groups_owners', 'groups_thumbs', 'groups_posts'])) LOOP
        query := interactions_query_builder(tbl, me, grp, true);
        FOR ret IN EXECUTE query LOOP
            RETURN NEXT ret;
        END LOOP;
    END LOOP;
   RETURN;
END $$;


ALTER FUNCTION public.group_interactions(me bigint, grp bigint) OWNER TO test_db;

--
-- Name: group_post_control(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION group_post_control() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE group_owner int8;
        open_group boolean;
        members int8[];
BEGIN
    NEW.message = message_control(NEW.message);

    IF TG_OP = 'INSERT' THEN -- no flood control on update
        PERFORM flood_control('"groups_posts"', NEW."from", NEW.message);
    END IF;

    SELECT "from" INTO group_owner FROM "groups_owners" WHERE "to" = NEW."to";
    SELECT "open" INTO open_group FROM groups WHERE "counter" = NEW."to";

    IF group_owner <> NEW."from" AND
        (
            open_group IS FALSE AND NEW."from" NOT IN (
                SELECT "from" FROM "groups_members" WHERE "to" = NEW."to" )
        )
    THEN
        RAISE EXCEPTION 'CLOSED_PROJECT';
    END IF;

    IF open_group IS FALSE THEN -- if the group is closed, blacklist works
        PERFORM blacklist_control(NEW."from", group_owner);
    END IF;

    IF TG_OP = 'UPDATE' THEN
        SELECT NOW() INTO NEW.time;
    ELSE
        SELECT "pid" INTO NEW.pid FROM (
            SELECT COALESCE( (SELECT "pid" + 1 as "pid" FROM "groups_posts"
            WHERE "to" = NEW."to"
            ORDER BY "hpid" DESC
            FETCH FIRST ROW ONLY), 1) AS "pid"
        ) AS T1;
    END IF;

    IF NEW."from" <> group_owner AND NEW."from" NOT IN (
        SELECT "from" FROM "groups_members" WHERE "to" = NEW."to"
    ) THEN
        SELECT false INTO NEW.news; -- Only owner and members can send news
    END IF;

    -- if to = GLOBAL_NEWS set the news filed to true
    IF NEW."to" = (SELECT counter FROM special_groups where "role" = 'GLOBAL_NEWS') THEN
        SELECT true INTO NEW.news;
    END IF;

    RETURN NEW;
END $$;


ALTER FUNCTION public.group_post_control() OWNER TO test_db;

--
-- Name: groups_post_update(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION groups_post_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO groups_posts_revisions(hpid, time, message, rev_no) VALUES(OLD.hpid, OLD.time, OLD.message,
        (SELECT COUNT(hpid) +1 FROM groups_posts_revisions WHERE hpid = OLD.hpid));

    PERFORM hashtag(NEW.message, NEW.hpid, true);
    PERFORM mention(NEW."from", NEW.message, NEW.hpid, true);
    RETURN NULL;
END $$;


ALTER FUNCTION public.groups_post_update() OWNER TO test_db;

--
-- Name: handle_groups_on_user_delete(bigint); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION handle_groups_on_user_delete(usercounter bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$
declare r RECORD;
newOwner int8;
begin
    FOR r IN SELECT "to" FROM "groups_owners" WHERE "from" = userCounter LOOP
        IF EXISTS (select "from" FROM groups_members where "to" = r."to") THEN
            SELECT gm."from" INTO newowner FROM groups_members gm
            WHERE "to" = r."to" AND "time" = (
                SELECT min(time) FROM groups_members WHERE "to" = r."to"
            );
            
            UPDATE "groups_owners" SET "from" = newOwner, to_notify = TRUE WHERE "to" = r."to";
            DELETE FROM groups_members WHERE "from" = newOwner;
        END IF;
        -- else, the foreing key remains and the group will be dropped
    END LOOP;
END $$;


ALTER FUNCTION public.handle_groups_on_user_delete(usercounter bigint) OWNER TO test_db;

--
-- Name: hashtag(text, bigint, boolean); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION hashtag(message text, hpid bigint, grp boolean) RETURNS void
    LANGUAGE plpgsql
    AS $$
declare field text;
BEGIN
    IF grp THEN
        field := 'g_hpid';
    ELSE
        field := 'u_hpid';
    END IF;

    message = quote_literal(message);

    EXECUTE '
    insert into posts_classification(' || field || ' , tag)
    select distinct ' || hpid ||', tmp.matchedTag[1] from (
        -- 1: existing hashtags
       select regexp_matches(' ||
         regexp_replace(regexp_replace(
         regexp_replace(regexp_replace(
         regexp_replace(regexp_replace(
         regexp_replace(regexp_replace(message,
            '\[url[^\]]*\](.+?)\[/url\]',' \1 ','gi'),
            '\[code=[^\]]+\].+?\[/code\]',' ','gi'),
            '\[video\].+?\[/video\]',' ','gi'),
            '\[yt\].+?\[/yt\]',' ','gi'),
            '\[youtube\].+?\[/youtube\]',' ','gi'),
            '\[music\].+?\[/music\]',' ','gi'),
            '\[img\].+?\[/img\]',' ','gi'),
            '\[twitter\].+?\[/twitter\]',' ','gi')
         || ', ''(#(?!039;)[\w]{1,34})'', ''gi'')
        as matchedTag
            union distinct -- 2: spoiler
        select concat(''{#'', a.matchedTag[1], ''}'')::text[] from (
            select regexp_matches(' || message || ', ''\[spoiler=([\w]{1,34})\]'', ''gi'')
            as matchedTag
        ) as a
            union distinct -- 3: languages
         select concat(''{#'', b.matchedTag[1], ''}'')::text[] from (
             select regexp_matches(' || message || ', ''\[code=([\w]{1,34})\]'', ''gi'')
            as matchedTag
        ) as b
    ) tmp
    where not exists (
        select 1 from posts_classification p where ' || field ||'  = ' || hpid || ' and p.tag = tmp.matchedTag[1]
    )
    ';
END $$;


ALTER FUNCTION public.hashtag(message text, hpid bigint, grp boolean) OWNER TO test_db;

--
-- Name: interactions_query_builder(text, bigint, bigint, boolean); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION interactions_query_builder(tbl text, me bigint, other bigint, grp boolean) RETURNS text
    LANGUAGE plpgsql
    AS $$
declare ret text;
begin
    ret := 'SELECT ''' || tbl || '''::text';
    IF NOT grp THEN
        ret = ret || ' ,t."from", t."to"';
    END IF;
    ret = ret || ', t."time" ';
    --joins
        IF tbl ILIKE '%comments' OR tbl = 'thumbs' OR tbl = 'groups_thumbs' OR tbl ILIKE '%lurkers'
        THEN

            ret = ret || ' , p."pid", p."to" FROM "' || tbl || '" t INNER JOIN "';
            IF grp THEN
                ret = ret || 'groups_';
            END IF;
            ret = ret || 'posts" p ON p.hpid = t.hpid';

        ELSIF tbl ILIKE '%posts' THEN

            ret = ret || ', "pid", "to" FROM "' || tbl || '" t';

        ELSIF tbl ILIKE '%comment_thumbs' THEN

            ret = ret || ', p."pid", p."to" FROM "';

            IF grp THEN
                ret = ret || 'groups_';
            END IF;

            ret = ret || 'comments" c INNER JOIN "' || tbl || '" t
                ON t.hcid = c.hcid
            INNER JOIN "';

            IF grp THEN
                ret = ret || 'groups_';
            END IF;

            ret = ret || 'posts" p ON p.hpid = c.hpid';

        ELSE
            ret = ret || ', null::int8, null::int8  FROM ' || tbl || ' t ';

        END IF;
    --conditions
    ret = ret || ' WHERE (t."from" = '|| me ||' AND t."to" = '|| other ||')';

    IF NOT grp THEN
        ret = ret || ' OR (t."from" = '|| other ||' AND t."to" = '|| me ||')';
    END IF;

    RETURN ret;
end $$;


ALTER FUNCTION public.interactions_query_builder(tbl text, me bigint, other bigint, grp boolean) OWNER TO test_db;

--
-- Name: login(text, text); Type: FUNCTION; Schema: public; Owner: %%postgres%%
--

CREATE FUNCTION login(_username text, _pass text, OUT ret boolean) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
begin
	-- begin legacy migration
	if (select length(password) = 40
			from users
			where lower(username) = lower(_username) and password = encode(digest(_pass, 'SHA1'), 'HEX')
	) then
		update users set password = crypt(_pass, gen_salt('bf', 7)) where lower(username) = lower(_username);
	end if;
	-- end legacy migration
	select password = crypt(_pass, users.password) into ret
	from users
	where lower(username) = lower(_username);
end $$;


ALTER FUNCTION public.login(_username text, _pass text, OUT ret boolean) OWNER TO %%postgres%%;

--
-- Name: mention(bigint, text, bigint, boolean); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION mention(me bigint, message text, hpid bigint, grp boolean) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE field text;
    posts_notify_tbl text;
    comments_notify_tbl text;
    posts_no_notify_tbl text;
    comments_no_notify_tbl text;
    project record;
    owner int8;
    other int8;
    matches text[];
    username text;
    found boolean;
BEGIN
    -- prepare tables
    IF grp THEN
        EXECUTE 'SELECT closed FROM groups_posts WHERE hpid = ' || hpid INTO found;
        IF found THEN
            RETURN;
        END IF;
        posts_notify_tbl = 'groups_notify';
        posts_no_notify_tbl = 'groups_posts_no_notify';

        comments_notify_tbl = 'groups_comments_notify';
        comments_no_notify_tbl = 'groups_comments_no_notify';
    ELSE
        EXECUTE 'SELECT closed FROM posts WHERE hpid = ' || hpid INTO found;
        IF found THEN
            RETURN;
        END IF;
        posts_notify_tbl = 'posts_notify';
        posts_no_notify_tbl = 'posts_no_notify';

        comments_notify_tbl = 'comments_notify';
        comments_no_notify_tbl = 'comments_no_notify';           
    END IF;

    -- extract [user]username[/user]
    message = quote_literal(message);
    FOR matches IN
        EXECUTE 'select regexp_matches(' || message || ',
            ''(?!\[(?:url|code|video|yt|youtube|music|img|twitter)[^\]]*\])\[user\](.+?)\[/user\](?![^\[]*\[\/(?:url|code|video|yt|youtube|music|img|twitter)\])'', ''gi''
        )' LOOP

        username = matches[1];
        -- if username exists
        EXECUTE 'SELECT counter FROM users WHERE LOWER(username) = LOWER(' || quote_literal(username) || ');' INTO other;
        IF other IS NULL OR other = me THEN
            CONTINUE;
        END IF;

        -- check if 'other' is in notfy list.
        -- if it is, continue, since he will receive notification about this post anyway
        EXECUTE 'SELECT ' || other || ' IN (
            (SELECT "to" FROM "' || posts_notify_tbl || '" WHERE hpid = ' || hpid || ')
                UNION
           (SELECT "to" FROM "' || comments_notify_tbl || '" WHERE hpid = ' || hpid || ')
        )' INTO found;

        IF found THEN
            CONTINUE;
        END IF;

        -- check if 'ohter' disabled notification from post hpid, if yes -> skip
        EXECUTE 'SELECT ' || other || ' IN (SELECT "user" FROM "' || posts_no_notify_tbl || '" WHERE hpid = ' || hpid || ')' INTO found;
        IF found THEN
            CONTINUE;
        END IF;

        --check if 'other' disabled notification from 'me' in post hpid, if yes -> skip
        EXECUTE 'SELECT ' || other || ' IN (SELECT "to" FROM "' || comments_no_notify_tbl || '" WHERE hpid = ' || hpid || ' AND "from" = ' || me || ')' INTO found;

        IF found THEN
            CONTINUE;
        END IF;

        -- blacklist control
        BEGIN
            PERFORM blacklist_control(me, other);

            IF grp THEN
                EXECUTE 'SELECT counter, visible
                FROM groups WHERE "counter" = (
                    SELECT "to" FROM groups_posts p WHERE p.hpid = ' || hpid || ');'
                INTO project;

                select "from" INTO owner FROM groups_owners WHERE "to" = project.counter;
                -- other can't access groups if the owner blacklisted him
                PERFORM blacklist_control(owner, other);

                -- if the project is NOT visible and other is not the owner or a member
                IF project.visible IS FALSE AND other NOT IN (
                    SELECT "from" FROM groups_members WHERE "to" = project.counter
                        UNION
                      SELECT owner
                    ) THEN
                    RETURN;
                END IF;
            END IF;

        EXCEPTION
            WHEN OTHERS THEN
                CONTINUE;
        END;

        IF grp THEN
            field := 'g_hpid';
        ELSE
            field := 'u_hpid';
        END IF;

        -- if here and mentions does not exists, insert
        EXECUTE 'INSERT INTO mentions(' || field || ' , "from", "to")
        SELECT ' || hpid || ', ' || me || ', '|| other ||'
        WHERE NOT EXISTS (
            SELECT 1 FROM mentions
            WHERE "' || field || '" = ' || hpid || ' AND "to" = ' || other || '
        )';

    END LOOP;

END $$;


ALTER FUNCTION public.mention(me bigint, message text, hpid bigint, grp boolean) OWNER TO test_db;

--
-- Name: message_control(text); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION message_control(message text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE ret text;
BEGIN
    SELECT trim(message) INTO ret;
    IF char_length(ret) = 0 THEN
        RAISE EXCEPTION 'NO_EMPTY_MESSAGE';
    END IF;
    RETURN ret;
END $$;


ALTER FUNCTION public.message_control(message text) OWNER TO test_db;

--
-- Name: post_control(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION post_control() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.message = message_control(NEW.message);

    IF TG_OP = 'INSERT' THEN -- no flood control on update
        PERFORM flood_control('"posts"', NEW."from", NEW.message);
    END IF;

    PERFORM blacklist_control(NEW."from", NEW."to");

    IF( NEW."to" <> NEW."from" AND
        (SELECT "closed" FROM "profiles" WHERE "counter" = NEW."to") IS TRUE AND 
        NEW."from" NOT IN (SELECT "to" FROM whitelist WHERE "from" = NEW."to")
      )
    THEN
        RAISE EXCEPTION 'CLOSED_PROFILE';
    END IF;


    IF TG_OP = 'UPDATE' THEN -- no pid increment
        SELECT NOW() INTO NEW.time;
    ELSE
        SELECT "pid" INTO NEW.pid FROM (
            SELECT COALESCE( (SELECT "pid" + 1 as "pid" FROM "posts"
            WHERE "to" = NEW."to"
            ORDER BY "hpid" DESC
            FETCH FIRST ROW ONLY), 1 ) AS "pid"
        ) AS T1;
    END IF;

    IF NEW."to" <> NEW."from" THEN -- can't write news to others board
        SELECT false INTO NEW.news;
    END IF;

    -- if to = GLOBAL_NEWS set the news filed to true
    IF NEW."to" = (SELECT counter FROM special_users where "role" = 'GLOBAL_NEWS') THEN
        SELECT true INTO NEW.news;
    END IF;
    
    RETURN NEW;
END $$;


ALTER FUNCTION public.post_control() OWNER TO test_db;

--
-- Name: post_update(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION post_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO posts_revisions(hpid, time, message, rev_no) VALUES(OLD.hpid, OLD.time, OLD.message,
        (SELECT COUNT(hpid) +1 FROM posts_revisions WHERE hpid = OLD.hpid));

    PERFORM hashtag(NEW.message, NEW.hpid, false);
    PERFORM mention(NEW."from", NEW.message, NEW.hpid, false);
    RETURN NULL;
END $$;


ALTER FUNCTION public.post_update() OWNER TO test_db;

--
-- Name: user_comment(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION user_comment() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM hashtag(NEW.message, NEW.hpid, false);
    PERFORM mention(NEW."from", NEW.message, NEW.hpid, false);
    -- edit support
    IF TG_OP = 'UPDATE' THEN
        INSERT INTO comments_revisions(hcid, time, message, rev_no)
        VALUES(OLD.hcid, OLD.time, OLD.message, (
            SELECT COUNT(hcid) + 1 FROM comments_revisions WHERE hcid = OLD.hcid
        ));

         --notify only if it's the last comment in the post
        IF OLD.hcid <> (SELECT MAX(hcid) FROM comments WHERE hpid = NEW.hpid) THEN
            RETURN NULL;
        END IF;
    END IF;

    -- if I commented the post, I stop lurking
    DELETE FROM "lurkers" WHERE "hpid" = NEW."hpid" AND "from" = NEW."from";

    WITH no_notify("user") AS (
        -- blacklist
        (
            SELECT "from" FROM "blacklist" WHERE "to" = NEW."from"
                UNION
            SELECT "to" FROM "blacklist" WHERE "from" = NEW."from"
        )
        UNION -- users that locked the notifications for all the thread
            SELECT "user" FROM "posts_no_notify" WHERE "hpid" = NEW."hpid"
        UNION -- users that locked notifications from me in this thread
            SELECT "to" FROM "comments_no_notify" WHERE "from" = NEW."from" AND "hpid" = NEW."hpid"
        UNION -- users mentioned in this post (already notified, with the mention)
            SELECT "to" FROM "mentions" WHERE "u_hpid" = NEW.hpid AND to_notify IS TRUE
        UNION
            SELECT NEW."from"
    ),
    to_notify("user") AS (
            SELECT DISTINCT "from" FROM "comments" WHERE "hpid" = NEW."hpid"
        UNION
            SELECT "from" FROM "lurkers" WHERE "hpid" = NEW."hpid"
        UNION
            SELECT "from" FROM "posts" WHERE "hpid" = NEW."hpid"
        UNION
            SELECT "to" FROM "posts" WHERE "hpid" = NEW."hpid"
    ),
    real_notify("user") AS (
        -- avoid to add rows with the same primary key
        SELECT "user" FROM (
            SELECT "user" FROM to_notify
                EXCEPT
            (
                SELECT "user" FROM no_notify
             UNION
                SELECT "to" AS "user" FROM "comments_notify" WHERE "hpid" = NEW."hpid"
            )
        ) AS T1
    )

    INSERT INTO "comments_notify"("from","to","hpid","time") (
        SELECT NEW."from", "user", NEW."hpid", NEW."time" FROM real_notify
    );

    RETURN NULL;
END $$;


ALTER FUNCTION public.user_comment() OWNER TO test_db;

--
-- Name: user_comment_edit_control(); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION user_comment_edit_control() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF OLD.editable IS FALSE THEN
        RAISE EXCEPTION 'NOT_EDITABLE';
    END IF;

    -- update time
    SELECT NOW() INTO NEW.time;

    NEW.message = message_control(NEW.message);
    PERFORM flood_control('"comments"', NEW."from", NEW.message);
    PERFORM blacklist_control(NEW."from", NEW."to");

    RETURN NEW;
END $$;


ALTER FUNCTION public.user_comment_edit_control() OWNER TO test_db;

--
-- Name: user_interactions(bigint, bigint); Type: FUNCTION; Schema: public; Owner: test_db
--

CREATE FUNCTION user_interactions(me bigint, other bigint) RETURNS SETOF record
    LANGUAGE plpgsql
    AS $$
DECLARE tbl text;
        ret record;
        query text;
begin
    FOR tbl IN (SELECT unnest(array['blacklist', 'comment_thumbs', 'comments', 'followers', 'lurkers', 'mentions', 'pms', 'posts', 'whitelist'])) LOOP
        query := interactions_query_builder(tbl, me, other, false);
        FOR ret IN EXECUTE query LOOP
            RETURN NEXT ret;
        END LOOP;
    END LOOP;
   RETURN;
END $$;


ALTER FUNCTION public.user_interactions(me bigint, other bigint) OWNER TO test_db;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: ban; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE ban (
    "user" bigint NOT NULL,
    motivation text DEFAULT 'No reason given'::text NOT NULL,
    "time" timestamp(0) with time zone DEFAULT now() NOT NULL
);


ALTER TABLE ban OWNER TO test_db;

--
-- Name: blacklist; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE blacklist (
    "from" bigint NOT NULL,
    "to" bigint NOT NULL,
    motivation text DEFAULT 'No reason given'::text,
    "time" timestamp(0) with time zone DEFAULT now() NOT NULL,
    counter bigint NOT NULL
);


ALTER TABLE blacklist OWNER TO test_db;

--
-- Name: blacklist_id_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE blacklist_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE blacklist_id_seq OWNER TO test_db;

--
-- Name: blacklist_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE blacklist_id_seq OWNED BY blacklist.counter;


--
-- Name: bookmarks; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE bookmarks (
    "from" bigint NOT NULL,
    hpid bigint NOT NULL,
    "time" timestamp(0) with time zone DEFAULT now() NOT NULL,
    counter bigint NOT NULL
);


ALTER TABLE bookmarks OWNER TO test_db;

--
-- Name: bookmarks_id_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE bookmarks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE bookmarks_id_seq OWNER TO test_db;

--
-- Name: bookmarks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE bookmarks_id_seq OWNED BY bookmarks.counter;


--
-- Name: comment_thumbs; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE comment_thumbs (
    hcid bigint NOT NULL,
    "from" bigint NOT NULL,
    vote smallint NOT NULL,
    "time" timestamp(0) with time zone DEFAULT now() NOT NULL,
    "to" bigint NOT NULL,
    counter bigint NOT NULL,
    CONSTRAINT chkvote CHECK ((vote = ANY (ARRAY[(-1), 0, 1])))
);


ALTER TABLE comment_thumbs OWNER TO test_db;

--
-- Name: comment_thumbs_id_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE comment_thumbs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE comment_thumbs_id_seq OWNER TO test_db;

--
-- Name: comment_thumbs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE comment_thumbs_id_seq OWNED BY comment_thumbs.counter;


--
-- Name: comments; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE comments (
    "from" bigint NOT NULL,
    "to" bigint NOT NULL,
    hpid bigint NOT NULL,
    message text NOT NULL,
    "time" timestamp(0) with time zone DEFAULT now() NOT NULL,
    hcid bigint NOT NULL,
    editable boolean DEFAULT true NOT NULL
);


ALTER TABLE comments OWNER TO test_db;

--
-- Name: comments_hcid_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE comments_hcid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE comments_hcid_seq OWNER TO test_db;

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
    "time" timestamp(0) with time zone DEFAULT now() NOT NULL,
    counter bigint NOT NULL
);


ALTER TABLE comments_no_notify OWNER TO test_db;

--
-- Name: comments_no_notify_id_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE comments_no_notify_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE comments_no_notify_id_seq OWNER TO test_db;

--
-- Name: comments_no_notify_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE comments_no_notify_id_seq OWNED BY comments_no_notify.counter;


--
-- Name: comments_notify; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE comments_notify (
    "from" bigint NOT NULL,
    "to" bigint NOT NULL,
    hpid bigint NOT NULL,
    "time" timestamp(0) with time zone DEFAULT now() NOT NULL,
    counter bigint NOT NULL
);


ALTER TABLE comments_notify OWNER TO test_db;

--
-- Name: comments_notify_id_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE comments_notify_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE comments_notify_id_seq OWNER TO test_db;

--
-- Name: comments_notify_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE comments_notify_id_seq OWNED BY comments_notify.counter;


--
-- Name: comments_revisions; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE comments_revisions (
    hcid bigint NOT NULL,
    message text NOT NULL,
    "time" timestamp(0) with time zone NOT NULL,
    rev_no integer DEFAULT 0 NOT NULL,
    counter bigint NOT NULL
);


ALTER TABLE comments_revisions OWNER TO test_db;

--
-- Name: comments_revisions_id_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE comments_revisions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE comments_revisions_id_seq OWNER TO test_db;

--
-- Name: comments_revisions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE comments_revisions_id_seq OWNED BY comments_revisions.counter;


--
-- Name: deleted_users; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE deleted_users (
    counter bigint NOT NULL,
    username character varying(90) NOT NULL,
    "time" timestamp(0) with time zone DEFAULT now() NOT NULL,
    motivation text
);


ALTER TABLE deleted_users OWNER TO test_db;

--
-- Name: flood_limits; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE flood_limits (
    table_name regclass NOT NULL,
    "time" interval minute to second NOT NULL
);


ALTER TABLE flood_limits OWNER TO test_db;

--
-- Name: followers; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE followers (
    "from" bigint NOT NULL,
    "to" bigint NOT NULL,
    to_notify boolean DEFAULT true NOT NULL,
    "time" timestamp(0) with time zone DEFAULT now() NOT NULL,
    counter bigint NOT NULL
);


ALTER TABLE followers OWNER TO test_db;

--
-- Name: followers_id_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE followers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE followers_id_seq OWNER TO test_db;

--
-- Name: followers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE followers_id_seq OWNED BY followers.counter;


--
-- Name: groups; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE groups (
    counter bigint NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    name character varying(30) NOT NULL,
    private boolean DEFAULT false NOT NULL,
    photo character varying(350) DEFAULT NULL::character varying,
    website character varying(350) DEFAULT NULL::character varying,
    goal text DEFAULT ''::text NOT NULL,
    visible boolean DEFAULT true NOT NULL,
    open boolean DEFAULT false NOT NULL,
    creation_time timestamp(0) with time zone DEFAULT now() NOT NULL
);


ALTER TABLE groups OWNER TO test_db;

--
-- Name: groups_bookmarks; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE groups_bookmarks (
    "from" bigint NOT NULL,
    hpid bigint NOT NULL,
    "time" timestamp(0) with time zone DEFAULT now() NOT NULL,
    counter bigint NOT NULL
);


ALTER TABLE groups_bookmarks OWNER TO test_db;

--
-- Name: groups_bookmarks_id_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE groups_bookmarks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE groups_bookmarks_id_seq OWNER TO test_db;

--
-- Name: groups_bookmarks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE groups_bookmarks_id_seq OWNED BY groups_bookmarks.counter;


--
-- Name: groups_comment_thumbs; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE groups_comment_thumbs (
    hcid bigint NOT NULL,
    "from" bigint NOT NULL,
    vote smallint NOT NULL,
    "time" timestamp(0) with time zone DEFAULT now() NOT NULL,
    "to" bigint NOT NULL,
    counter bigint NOT NULL,
    CONSTRAINT chkgvote CHECK ((vote = ANY (ARRAY[(-1), 0, 1])))
);


ALTER TABLE groups_comment_thumbs OWNER TO test_db;

--
-- Name: groups_comment_thumbs_id_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE groups_comment_thumbs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE groups_comment_thumbs_id_seq OWNER TO test_db;

--
-- Name: groups_comment_thumbs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE groups_comment_thumbs_id_seq OWNED BY groups_comment_thumbs.counter;


--
-- Name: groups_comments; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE groups_comments (
    "from" bigint NOT NULL,
    "to" bigint NOT NULL,
    hpid bigint NOT NULL,
    message text NOT NULL,
    "time" timestamp(0) with time zone DEFAULT now() NOT NULL,
    hcid bigint NOT NULL,
    editable boolean DEFAULT true NOT NULL
);


ALTER TABLE groups_comments OWNER TO test_db;

--
-- Name: groups_comments_hcid_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE groups_comments_hcid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE groups_comments_hcid_seq OWNER TO test_db;

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
    "time" timestamp(0) with time zone DEFAULT now() NOT NULL,
    counter bigint NOT NULL
);


ALTER TABLE groups_comments_no_notify OWNER TO test_db;

--
-- Name: groups_comments_no_notify_id_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE groups_comments_no_notify_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE groups_comments_no_notify_id_seq OWNER TO test_db;

--
-- Name: groups_comments_no_notify_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE groups_comments_no_notify_id_seq OWNED BY groups_comments_no_notify.counter;


--
-- Name: groups_comments_notify; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE groups_comments_notify (
    "from" bigint NOT NULL,
    "to" bigint NOT NULL,
    hpid bigint NOT NULL,
    "time" timestamp(0) with time zone DEFAULT now() NOT NULL,
    counter bigint NOT NULL
);


ALTER TABLE groups_comments_notify OWNER TO test_db;

--
-- Name: groups_comments_notify_id_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE groups_comments_notify_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE groups_comments_notify_id_seq OWNER TO test_db;

--
-- Name: groups_comments_notify_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE groups_comments_notify_id_seq OWNED BY groups_comments_notify.counter;


--
-- Name: groups_comments_revisions; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE groups_comments_revisions (
    hcid bigint NOT NULL,
    message text NOT NULL,
    "time" timestamp(0) with time zone NOT NULL,
    rev_no integer DEFAULT 0 NOT NULL,
    counter bigint NOT NULL
);


ALTER TABLE groups_comments_revisions OWNER TO test_db;

--
-- Name: groups_comments_revisions_id_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE groups_comments_revisions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE groups_comments_revisions_id_seq OWNER TO test_db;

--
-- Name: groups_comments_revisions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE groups_comments_revisions_id_seq OWNED BY groups_comments_revisions.counter;


--
-- Name: groups_counter_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE groups_counter_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE groups_counter_seq OWNER TO test_db;

--
-- Name: groups_counter_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE groups_counter_seq OWNED BY groups.counter;


--
-- Name: groups_followers; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE groups_followers (
    "to" bigint NOT NULL,
    "from" bigint NOT NULL,
    "time" timestamp(0) with time zone DEFAULT now() NOT NULL,
    to_notify boolean DEFAULT true NOT NULL,
    counter bigint NOT NULL
);


ALTER TABLE groups_followers OWNER TO test_db;

--
-- Name: groups_followers_id_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE groups_followers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE groups_followers_id_seq OWNER TO test_db;

--
-- Name: groups_followers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE groups_followers_id_seq OWNED BY groups_followers.counter;


--
-- Name: groups_lurkers; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE groups_lurkers (
    "from" bigint NOT NULL,
    hpid bigint NOT NULL,
    "time" timestamp(0) with time zone DEFAULT now() NOT NULL,
    "to" bigint NOT NULL,
    counter bigint NOT NULL
);


ALTER TABLE groups_lurkers OWNER TO test_db;

--
-- Name: groups_lurkers_id_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE groups_lurkers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE groups_lurkers_id_seq OWNER TO test_db;

--
-- Name: groups_lurkers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE groups_lurkers_id_seq OWNED BY groups_lurkers.counter;


--
-- Name: groups_members; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE groups_members (
    "to" bigint NOT NULL,
    "from" bigint NOT NULL,
    "time" timestamp(0) with time zone DEFAULT now() NOT NULL,
    to_notify boolean DEFAULT true NOT NULL,
    counter bigint NOT NULL
);


ALTER TABLE groups_members OWNER TO test_db;

--
-- Name: groups_members_id_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE groups_members_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE groups_members_id_seq OWNER TO test_db;

--
-- Name: groups_members_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE groups_members_id_seq OWNED BY groups_members.counter;


--
-- Name: groups_notify; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE groups_notify (
    "from" bigint NOT NULL,
    "to" bigint NOT NULL,
    "time" timestamp(0) with time zone DEFAULT now() NOT NULL,
    hpid bigint NOT NULL,
    counter bigint NOT NULL
);


ALTER TABLE groups_notify OWNER TO test_db;

--
-- Name: groups_notify_id_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE groups_notify_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE groups_notify_id_seq OWNER TO test_db;

--
-- Name: groups_notify_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE groups_notify_id_seq OWNED BY groups_notify.counter;


--
-- Name: groups_owners; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE groups_owners (
    "to" bigint NOT NULL,
    "from" bigint NOT NULL,
    "time" timestamp(0) with time zone DEFAULT now() NOT NULL,
    to_notify boolean DEFAULT false NOT NULL,
    counter bigint NOT NULL
);


ALTER TABLE groups_owners OWNER TO test_db;

--
-- Name: groups_owners_id_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE groups_owners_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE groups_owners_id_seq OWNER TO test_db;

--
-- Name: groups_owners_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE groups_owners_id_seq OWNED BY groups_owners.counter;


--
-- Name: groups_posts; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE groups_posts (
    hpid bigint NOT NULL,
    "from" bigint NOT NULL,
    "to" bigint NOT NULL,
    pid bigint NOT NULL,
    message text NOT NULL,
    "time" timestamp(0) with time zone DEFAULT now() NOT NULL,
    news boolean DEFAULT false NOT NULL,
    lang character varying(2) DEFAULT 'en'::character varying NOT NULL,
    closed boolean DEFAULT false NOT NULL
);


ALTER TABLE groups_posts OWNER TO test_db;

--
-- Name: groups_posts_hpid_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE groups_posts_hpid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE groups_posts_hpid_seq OWNER TO test_db;

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
    "time" timestamp(0) with time zone DEFAULT now() NOT NULL,
    counter bigint NOT NULL
);


ALTER TABLE groups_posts_no_notify OWNER TO test_db;

--
-- Name: groups_posts_no_notify_id_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE groups_posts_no_notify_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE groups_posts_no_notify_id_seq OWNER TO test_db;

--
-- Name: groups_posts_no_notify_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE groups_posts_no_notify_id_seq OWNED BY groups_posts_no_notify.counter;


--
-- Name: groups_posts_revisions; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE groups_posts_revisions (
    hpid bigint NOT NULL,
    message text NOT NULL,
    "time" timestamp(0) with time zone NOT NULL,
    rev_no integer DEFAULT 0 NOT NULL,
    counter bigint NOT NULL
);


ALTER TABLE groups_posts_revisions OWNER TO test_db;

--
-- Name: groups_posts_revisions_id_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE groups_posts_revisions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE groups_posts_revisions_id_seq OWNER TO test_db;

--
-- Name: groups_posts_revisions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE groups_posts_revisions_id_seq OWNED BY groups_posts_revisions.counter;


--
-- Name: groups_thumbs; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE groups_thumbs (
    hpid bigint NOT NULL,
    "from" bigint NOT NULL,
    vote smallint NOT NULL,
    "time" timestamp(0) with time zone DEFAULT now() NOT NULL,
    "to" bigint NOT NULL,
    counter bigint NOT NULL,
    CONSTRAINT chkgvote CHECK ((vote = ANY (ARRAY[(-1), 0, 1])))
);


ALTER TABLE groups_thumbs OWNER TO test_db;

--
-- Name: groups_thumbs_id_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE groups_thumbs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE groups_thumbs_id_seq OWNER TO test_db;

--
-- Name: groups_thumbs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE groups_thumbs_id_seq OWNED BY groups_thumbs.counter;


--
-- Name: guests; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE guests (
    remote_addr inet NOT NULL,
    http_user_agent text NOT NULL,
    last timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE guests OWNER TO test_db;

--
-- Name: lurkers; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE lurkers (
    "from" bigint NOT NULL,
    hpid bigint NOT NULL,
    "time" timestamp(0) with time zone DEFAULT now() NOT NULL,
    "to" bigint NOT NULL,
    counter bigint NOT NULL
);


ALTER TABLE lurkers OWNER TO test_db;

--
-- Name: lurkers_id_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE lurkers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE lurkers_id_seq OWNER TO test_db;

--
-- Name: lurkers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE lurkers_id_seq OWNED BY lurkers.counter;


--
-- Name: mentions; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE mentions (
    id bigint NOT NULL,
    u_hpid bigint,
    g_hpid bigint,
    "from" bigint NOT NULL,
    "to" bigint NOT NULL,
    "time" timestamp(0) with time zone DEFAULT now() NOT NULL,
    to_notify boolean DEFAULT true NOT NULL,
    CONSTRAINT mentions_check CHECK (((u_hpid IS NOT NULL) OR (g_hpid IS NOT NULL)))
);


ALTER TABLE mentions OWNER TO test_db;

--
-- Name: mentions_id_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE mentions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE mentions_id_seq OWNER TO test_db;

--
-- Name: mentions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE mentions_id_seq OWNED BY mentions.id;


--
-- Name: pms; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE pms (
    "from" bigint NOT NULL,
    "to" bigint NOT NULL,
    "time" timestamp(0) with time zone DEFAULT now() NOT NULL,
    message text NOT NULL,
    to_read boolean DEFAULT true NOT NULL,
    pmid bigint NOT NULL
);


ALTER TABLE pms OWNER TO test_db;

--
-- Name: pms_pmid_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE pms_pmid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE pms_pmid_seq OWNER TO test_db;

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
    "time" timestamp(0) with time zone DEFAULT now() NOT NULL,
    lang character varying(2) DEFAULT 'en'::character varying NOT NULL,
    news boolean DEFAULT false NOT NULL,
    closed boolean DEFAULT false NOT NULL
);


ALTER TABLE posts OWNER TO test_db;

--
-- Name: posts_classification; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE posts_classification (
    id bigint NOT NULL,
    u_hpid bigint,
    g_hpid bigint,
    tag character varying(35) NOT NULL,
    CONSTRAINT posts_classification_check CHECK (((u_hpid IS NOT NULL) OR (g_hpid IS NOT NULL)))
);


ALTER TABLE posts_classification OWNER TO test_db;

--
-- Name: posts_classification_id_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE posts_classification_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE posts_classification_id_seq OWNER TO test_db;

--
-- Name: posts_classification_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE posts_classification_id_seq OWNED BY posts_classification.id;


--
-- Name: posts_hpid_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE posts_hpid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE posts_hpid_seq OWNER TO test_db;

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
    "time" timestamp(0) with time zone DEFAULT now() NOT NULL,
    counter bigint NOT NULL
);


ALTER TABLE posts_no_notify OWNER TO test_db;

--
-- Name: posts_no_notify_id_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE posts_no_notify_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE posts_no_notify_id_seq OWNER TO test_db;

--
-- Name: posts_no_notify_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE posts_no_notify_id_seq OWNED BY posts_no_notify.counter;


--
-- Name: posts_notify; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE posts_notify (
    "from" bigint NOT NULL,
    "to" bigint NOT NULL,
    hpid bigint NOT NULL,
    "time" timestamp(0) with time zone DEFAULT now() NOT NULL,
    counter bigint NOT NULL
);


ALTER TABLE posts_notify OWNER TO test_db;

--
-- Name: posts_notify_id_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE posts_notify_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE posts_notify_id_seq OWNER TO test_db;

--
-- Name: posts_notify_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE posts_notify_id_seq OWNED BY posts_notify.counter;


--
-- Name: posts_revisions; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE posts_revisions (
    hpid bigint NOT NULL,
    message text NOT NULL,
    "time" timestamp(0) with time zone NOT NULL,
    rev_no integer DEFAULT 0 NOT NULL,
    counter bigint NOT NULL
);


ALTER TABLE posts_revisions OWNER TO test_db;

--
-- Name: posts_revisions_id_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE posts_revisions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE posts_revisions_id_seq OWNER TO test_db;

--
-- Name: posts_revisions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE posts_revisions_id_seq OWNED BY posts_revisions.counter;


--
-- Name: profiles; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE profiles (
    counter bigint NOT NULL,
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
    pushregtime timestamp(0) with time zone DEFAULT now() NOT NULL,
    closed boolean DEFAULT false NOT NULL,
    template_variables json DEFAULT '{}'::json NOT NULL
);


ALTER TABLE profiles OWNER TO test_db;

--
-- Name: reset_requests; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE reset_requests (
    counter bigint NOT NULL,
    remote_addr inet NOT NULL,
    "time" timestamp with time zone DEFAULT now() NOT NULL,
    token character varying(32) NOT NULL,
    "to" bigint NOT NULL
);


ALTER TABLE reset_requests OWNER TO test_db;

--
-- Name: reset_requests_counter_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE reset_requests_counter_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE reset_requests_counter_seq OWNER TO test_db;

--
-- Name: reset_requests_counter_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE reset_requests_counter_seq OWNED BY reset_requests.counter;


--
-- Name: special_groups; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE special_groups (
    role character varying(20) NOT NULL,
    counter bigint NOT NULL
);


ALTER TABLE special_groups OWNER TO test_db;

--
-- Name: special_users; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE special_users (
    role character varying(20) NOT NULL,
    counter bigint NOT NULL
);


ALTER TABLE special_users OWNER TO test_db;

--
-- Name: thumbs; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE thumbs (
    hpid bigint NOT NULL,
    "from" bigint NOT NULL,
    vote smallint NOT NULL,
    "time" timestamp(0) with time zone DEFAULT now() NOT NULL,
    "to" bigint NOT NULL,
    counter bigint NOT NULL,
    CONSTRAINT chkvote CHECK ((vote = ANY (ARRAY[(-1), 0, 1])))
);


ALTER TABLE thumbs OWNER TO test_db;

--
-- Name: thumbs_id_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE thumbs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE thumbs_id_seq OWNER TO test_db;

--
-- Name: thumbs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE thumbs_id_seq OWNED BY thumbs.counter;


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
    password character varying(60) NOT NULL,
    name character varying(60) NOT NULL,
    surname character varying(60) NOT NULL,
    email character varying(350) NOT NULL,
    gender boolean NOT NULL,
    birth_date date NOT NULL,
    board_lang character varying(2) DEFAULT 'en'::character varying NOT NULL,
    timezone character varying(35) DEFAULT 'UTC'::character varying NOT NULL,
    viewonline boolean DEFAULT true NOT NULL,
    remote_addr inet DEFAULT '127.0.0.1'::inet NOT NULL,
    http_user_agent text DEFAULT ''::text NOT NULL,
    registration_time timestamp(0) with time zone DEFAULT now() NOT NULL
);


ALTER TABLE users OWNER TO test_db;

--
-- Name: users_counter_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE users_counter_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE users_counter_seq OWNER TO test_db;

--
-- Name: users_counter_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE users_counter_seq OWNED BY users.counter;


--
-- Name: whitelist; Type: TABLE; Schema: public; Owner: test_db; Tablespace: 
--

CREATE TABLE whitelist (
    "from" bigint NOT NULL,
    "to" bigint NOT NULL,
    "time" timestamp(0) with time zone DEFAULT now() NOT NULL,
    counter bigint NOT NULL
);


ALTER TABLE whitelist OWNER TO test_db;

--
-- Name: whitelist_id_seq; Type: SEQUENCE; Schema: public; Owner: test_db
--

CREATE SEQUENCE whitelist_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE whitelist_id_seq OWNER TO test_db;

--
-- Name: whitelist_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: test_db
--

ALTER SEQUENCE whitelist_id_seq OWNED BY whitelist.counter;


--
-- Name: counter; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY blacklist ALTER COLUMN counter SET DEFAULT nextval('blacklist_id_seq'::regclass);


--
-- Name: counter; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY bookmarks ALTER COLUMN counter SET DEFAULT nextval('bookmarks_id_seq'::regclass);


--
-- Name: counter; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY comment_thumbs ALTER COLUMN counter SET DEFAULT nextval('comment_thumbs_id_seq'::regclass);


--
-- Name: hcid; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY comments ALTER COLUMN hcid SET DEFAULT nextval('comments_hcid_seq'::regclass);


--
-- Name: counter; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY comments_no_notify ALTER COLUMN counter SET DEFAULT nextval('comments_no_notify_id_seq'::regclass);


--
-- Name: counter; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY comments_notify ALTER COLUMN counter SET DEFAULT nextval('comments_notify_id_seq'::regclass);


--
-- Name: counter; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY comments_revisions ALTER COLUMN counter SET DEFAULT nextval('comments_revisions_id_seq'::regclass);


--
-- Name: counter; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY followers ALTER COLUMN counter SET DEFAULT nextval('followers_id_seq'::regclass);


--
-- Name: counter; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups ALTER COLUMN counter SET DEFAULT nextval('groups_counter_seq'::regclass);


--
-- Name: counter; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_bookmarks ALTER COLUMN counter SET DEFAULT nextval('groups_bookmarks_id_seq'::regclass);


--
-- Name: counter; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_comment_thumbs ALTER COLUMN counter SET DEFAULT nextval('groups_comment_thumbs_id_seq'::regclass);


--
-- Name: hcid; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_comments ALTER COLUMN hcid SET DEFAULT nextval('groups_comments_hcid_seq'::regclass);


--
-- Name: counter; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_comments_no_notify ALTER COLUMN counter SET DEFAULT nextval('groups_comments_no_notify_id_seq'::regclass);


--
-- Name: counter; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_comments_notify ALTER COLUMN counter SET DEFAULT nextval('groups_comments_notify_id_seq'::regclass);


--
-- Name: counter; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_comments_revisions ALTER COLUMN counter SET DEFAULT nextval('groups_comments_revisions_id_seq'::regclass);


--
-- Name: counter; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_followers ALTER COLUMN counter SET DEFAULT nextval('groups_followers_id_seq'::regclass);


--
-- Name: counter; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_lurkers ALTER COLUMN counter SET DEFAULT nextval('groups_lurkers_id_seq'::regclass);


--
-- Name: counter; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_members ALTER COLUMN counter SET DEFAULT nextval('groups_members_id_seq'::regclass);


--
-- Name: counter; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_notify ALTER COLUMN counter SET DEFAULT nextval('groups_notify_id_seq'::regclass);


--
-- Name: counter; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_owners ALTER COLUMN counter SET DEFAULT nextval('groups_owners_id_seq'::regclass);


--
-- Name: hpid; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_posts ALTER COLUMN hpid SET DEFAULT nextval('groups_posts_hpid_seq'::regclass);


--
-- Name: counter; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_posts_no_notify ALTER COLUMN counter SET DEFAULT nextval('groups_posts_no_notify_id_seq'::regclass);


--
-- Name: counter; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_posts_revisions ALTER COLUMN counter SET DEFAULT nextval('groups_posts_revisions_id_seq'::regclass);


--
-- Name: counter; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_thumbs ALTER COLUMN counter SET DEFAULT nextval('groups_thumbs_id_seq'::regclass);


--
-- Name: counter; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY lurkers ALTER COLUMN counter SET DEFAULT nextval('lurkers_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY mentions ALTER COLUMN id SET DEFAULT nextval('mentions_id_seq'::regclass);


--
-- Name: pmid; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY pms ALTER COLUMN pmid SET DEFAULT nextval('pms_pmid_seq'::regclass);


--
-- Name: hpid; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY posts ALTER COLUMN hpid SET DEFAULT nextval('posts_hpid_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY posts_classification ALTER COLUMN id SET DEFAULT nextval('posts_classification_id_seq'::regclass);


--
-- Name: counter; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY posts_no_notify ALTER COLUMN counter SET DEFAULT nextval('posts_no_notify_id_seq'::regclass);


--
-- Name: counter; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY posts_notify ALTER COLUMN counter SET DEFAULT nextval('posts_notify_id_seq'::regclass);


--
-- Name: counter; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY posts_revisions ALTER COLUMN counter SET DEFAULT nextval('posts_revisions_id_seq'::regclass);


--
-- Name: counter; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY reset_requests ALTER COLUMN counter SET DEFAULT nextval('reset_requests_counter_seq'::regclass);


--
-- Name: counter; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY thumbs ALTER COLUMN counter SET DEFAULT nextval('thumbs_id_seq'::regclass);


--
-- Name: counter; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY users ALTER COLUMN counter SET DEFAULT nextval('users_counter_seq'::regclass);


--
-- Name: counter; Type: DEFAULT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY whitelist ALTER COLUMN counter SET DEFAULT nextval('whitelist_id_seq'::regclass);


--
-- Data for Name: ban; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY ban ("user", motivation, "time") FROM stdin;
\.


--
-- Data for Name: blacklist; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY blacklist ("from", "to", motivation, "time", counter) FROM stdin;
4	2	[big]Dirty peasant.[/big]	2014-10-09 07:55:21+00	1
1	5	You&#039;re an asshole :&gt;	2014-10-09 07:55:21+00	2
\.


--
-- Name: blacklist_id_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('blacklist_id_seq', 2, true);


--
-- Data for Name: bookmarks; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY bookmarks ("from", hpid, "time", counter) FROM stdin;
1	6	2014-04-26 15:10:12+00	1
3	13	2014-04-26 15:34:06+00	2
6	35	2014-04-26 16:08:29+00	3
1	38	2014-04-26 16:14:23+00	4
12	47	2014-04-26 16:36:42+00	5
12	44	2014-04-26 16:36:44+00	6
12	48	2014-04-26 16:36:45+00	7
6	54	2014-04-26 16:44:38+00	8
3	58	2014-04-26 18:16:35+00	9
\.


--
-- Name: bookmarks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('bookmarks_id_seq', 9, true);


--
-- Data for Name: comment_thumbs; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY comment_thumbs (hcid, "from", vote, "time", "to", counter) FROM stdin;
4	1	1	2014-10-09 07:55:21+00	2	1
17	3	1	2014-10-09 07:55:21+00	4	2
102	12	1	2014-10-09 07:55:21+00	12	3
103	12	1	2014-10-09 07:55:21+00	12	4
105	12	1	2014-10-09 07:55:21+00	12	5
108	12	1	2014-10-09 07:55:21+00	12	6
109	12	1	2014-10-09 07:55:21+00	12	7
156	1	1	2014-10-09 07:55:21+00	14	8
156	3	1	2014-10-09 07:55:21+00	14	9
159	3	1	2014-10-09 07:55:21+00	14	10
\.


--
-- Name: comment_thumbs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('comment_thumbs_id_seq', 10, true);


--
-- Data for Name: comments; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY comments ("from", "to", hpid, message, "time", hcid, editable) FROM stdin;
1	1	4	[img]https://fbcdn-sphotos-f-a.akamaihd.net/hphotos-ak-frc1/t1.0-9/q71/s720x720/10295706_754761757878221_576570612184366073_n.jpg[/img] SALVO HELP	2014-04-26 15:04:55+00	1	t
2	1	6	Non pi&ugrave;	2014-04-26 15:11:21+00	2	t
1	1	6	Ciao Peppa :&gt; benvenuta su NERDZ! Come hai trovato questo sito?	2014-04-26 15:12:26+00	3	t
1	2	8	HOLA PORTUGAL[hr][commentquote=[user]admin[/user]]HOLA PORTUGAL[/commentquote]	2014-04-26 15:13:28+00	4	t
2	1	6	[commentquote=[user]admin[/user]]Ciao Peppa :&gt; benvenuta su NERDZ! Come hai trovato questo sito?[/commentquote]Culo	2014-04-26 15:13:43+00	5	t
1	1	6	nn 6 simpa	2014-04-26 15:15:13+00	6	t
2	1	6	:&lt; ma sono sincera e pura. Anche se dal nome non si direbbe.	2014-04-26 15:16:48+00	7	t
1	1	6	E dal fatto che per disegnarti come base devo fare un pene? Come giustifichi questo?	2014-04-26 15:17:38+00	8	t
2	1	6	[commentquote=[user]admin[/user]]E dal fatto che per disegnarti come base devo fare un pene? Come giustifichi questo?[/commentquote]Queste sono insinuazioni prive di fondamento. Infatti se faccio un disegno di me... Oh wait.	2014-04-26 15:19:56+00	9	t
2	1	10	Meglio di Patrick c&#039;&egrave; solo Xeno	2014-04-26 15:26:27+00	10	t
1	1	10	Meglio di Xeno c&#039;&egrave; solo *	2014-04-26 15:26:46+00	11	t
3	3	11	I&#039;m doing some tests.\n\nI want to see mcilloni, my dear friend.	2014-04-26 15:27:19+00	12	t
2	1	10	Meglio di * c&#039;&egrave; solo Peppa. ALL HAIL PEPPAPIG!	2014-04-26 15:28:05+00	13	t
1	4	12	OMG GABEN, I LOVE YOU	2014-04-26 15:28:08+00	14	t
1	1	10	VAI VIA XENO	2014-04-26 15:28:24+00	15	t
2	1	10	[commentquote=[user]admin[/user]]VAI VIA XENO[/commentquote][commentquote=[user]admin[/user]]VAI VIA XENO[/commentquote][commentquote=[user]admin[/user]]VAI VIA XENO[/commentquote][commentquote=[user]admin[/user]]VAI VIA XENO[/commentquote][commentquote=[user]admin[/user]]VAI VIA XENO[/commentquote][commentquote=[user]admin[/user]]VAI VIA XENO[/commentquote][commentquote=[user]admin[/user]]VAI VIA XENO[/commentquote][commentquote=[user]admin[/user]]VAI VIA XENO[/commentquote][commentquote=[user]admin[/user]]VAI VIA XENO[/commentquote][commentquote=[user]admin[/user]]VAI VIA XENO[/commentquote]	2014-04-26 15:28:45+00	16	t
1	4	15	You&#039;re not funny :&lt;	2014-04-26 15:28:46+00	17	t
2	3	13	VAI VIA XENO!	2014-04-26 15:29:04+00	18	t
3	3	13	Who&#039;s Xeno?	2014-04-26 15:29:21+00	19	t
4	4	15	But it was worth the weight, wasn&#039;t it?	2014-04-26 15:29:23+00	20	t
2	4	12	Omg, gaben gimme steam&#039;s games plz	2014-04-26 15:29:36+00	21	t
2	3	13	YOU ARE XENO! &gt;VAI VIA	2014-04-26 15:30:08+00	22	t
4	4	12	Unfortunately that is not allowed, and your account has been permanently banned.	2014-04-26 15:30:40+00	23	t
1	4	15	It wasn&#039;t. Your sentence just killed me.	2014-04-26 15:30:48+00	24	t
1	4	12	[img]http://i.imgur.com/4VkOPTx.gif[/img] &lt;3&lt;3&lt;3	2014-04-26 15:31:24+00	25	t
4	4	15	I&#039;m sorry. Here, have some free Team Fortress 2 hats.	2014-04-26 15:31:30+00	26	t
4	4	12	[big]Glorious Gaben&#039;s beard[/big]	2014-04-26 15:31:56+00	27	t
4	4	16	[commentquote=[user]Gaben[/user]][big]Glorious Gaben&#039;s beard[/big][/commentquote]	2014-04-26 15:32:33+00	29	t
3	3	13	Please PeppaPig, you&#039;re not funny.\nGo away...	2014-04-26 15:32:41+00	30	t
1	3	13	There&#039;s a non-written rule on this website.\nIf someone ask &quot;who&#039;s xeno&quot;, well, this one is xeno.	2014-04-26 15:32:50+00	31	t
3	3	13	[commentquote=[user]admin[/user]]There&#039;s a non-written rule on this website.\nIf someone ask &quot;who&#039;s xeno&quot;, well, this one is xeno.[/commentquote]\nI don&#039;t like it.[hr]It&#039;s quite stupid that I&#039;m able to put a &quot;finger up&quot; or a &quot;finger down&quot; to my posts...	2014-04-26 15:33:56+00	32	t
1	3	13	Well, after a complex and long reflection about that. We decided that is not stupid. Even bit boards like reddit do this[hr]*big	2014-04-26 15:34:55+00	33	t
2	1	18	PEPPE CRILLIN E&#039; IL MIO DIO. IN PORTOGALLO E&#039; VENERATO DA GRANDI E PICCINI, SIAMO TUTTI GRILLINI.	2014-04-26 15:36:31+00	34	t
1	1	18	GRILINI BELI NON SAPEVO KE PEPPA FOSSE UNA PORTOGHESE CHE PARLA ITALIANO HOLA	2014-04-26 15:37:13+00	35	t
4	1	19	[img]https://scontent-a.xx.fbcdn.net/hphotos-prn1/t1/1526365_10153748828130093_531967148_n.jpg[/img]	2014-04-26 15:37:37+00	36	t
1	1	19	AWESOME DESKTOP. WHAT&#039;S THAT PLUG IN?	2014-04-26 15:38:13+00	37	t
4	1	19	Enhanced sexy look 2.0, released only for the Gabecube.	2014-04-26 15:39:18+00	38	t
1	1	19	DO WANT	2014-04-26 15:39:51+00	39	t
1	4	23	You&#039;re on the top of the world. Women loves you and even men do that.\nYou&#039;re the swaggest person on this stupid planet.\nTHANK YOU GABEN!\n\nHL3?	2014-04-26 15:43:28+00	40	t
1	2	14	pls, get a life	2014-04-26 15:43:53+00	41	t
4	1	22	I don&#039;t understand what did you say, but I am releasing the secret pictures of me and you, taken by an anonymous user yesterday night.\n[img]http://i.imgur.com/dbyH8Ke.jpg[/img]	2014-04-26 15:43:57+00	42	t
4	4	23	Please check NERDZilla.	2014-04-26 15:44:13+00	43	t
1	4	23	OH MY LORD	2014-04-26 15:44:44+00	44	t
2	1	19	[img]https://www.kirsle.net/creativity/articles/doswin31.png[/img]	2014-04-26 15:45:24+00	45	t
1	1	22	You confirmed HL3. My life has a sense now. I&#039;m proud if this pic.	2014-04-26 15:45:37+00	46	t
4	1	19	Blacklisting PeppaFag.	2014-04-26 15:45:46+00	47	t
1	1	19	PLS THIS IS VIRTULAL BOX PEPPA	2014-04-26 15:45:56+00	48	t
1	4	26	:o PLS NO	2014-04-26 15:48:02+00	49	t
5	5	27	Ask your sister	2014-04-26 15:49:24+00	50	t
1	5	27	This is not funny. Blacklisted :&gt;	2014-04-26 15:50:47+00	51	t
6	6	29	Qualcosa a met&agrave; fra i due	2014-04-26 15:52:07+00	52	t
1	6	29	ah scusa sei taliano, sar&agrave; il vero doch oppure no? dilemma del giorno[hr]NO PLS NON MI MENTIRE	2014-04-26 15:52:30+00	53	t
6	6	29	Dovrai fidarti di me, mi dispiace	2014-04-26 15:53:52+00	54	t
1	6	29	Non mi fido di uno che dice di essere un 88 pur essendo un 95. TU TROLLI.\nE si, mettere un numero alla fine del nickname indica l&#039;anno di nascita. LRN2MSN	2014-04-26 15:54:54+00	55	t
15	13	54	ghouloso	2014-04-26 18:08:59+00	155	t
1	6	31	Hai ragionissimo, indica il problema pls che debbo fixare	2014-04-26 15:55:19+00	56	t
6	6	31	Beh, ho cambiato nick in &quot;Doch&quot; e mi ha cambiato solo il link del profilo lol	2014-04-26 15:55:53+00	57	t
2	1	19	[commentquote=[user]admin[/user]]PLS THIS IS VIRTULAL BOX PEPPA[/commentquote]OH NOES, M&#039;HAI BECCATA D: Sto emulando win 3.1 su win 3.1 cuz im SWEG\n[yt]https://www.youtube.com/watch?v=KTJVlJ25S8c[/yt]	2014-04-26 15:55:56+00	58	t
2	6	29	VAI VIA XENO	2014-04-26 15:56:40+00	59	t
1	6	31	nosp&egrave;, manca la news e quello &egrave; l&#039;unico problema che mi viene in mente	2014-04-26 15:56:50+00	60	t
6	6	31	[commentquote=[user]admin[/user]]nosp&egrave;, manca la news e quello &egrave; l&#039;unico problema che mi viene in mente[/commentquote]^\nE magari che non cambia l&#039;utente che scrive i post ed i commenti? asd[hr]il link del mio profilo &egrave; [url]http://datcanada.dyndns.org/Doch.[/url]	2014-04-26 15:57:48+00	61	t
2	1	24	&gt;[FR] Je suis un fille fillo\nMI STAI INSULTANDO? EH? CE L&#039;HAI CON ME? EH? TI SPACCIO LA FACCIA!	2014-04-26 15:58:28+00	62	t
6	6	29	[commentquote=[user]admin[/user]]Non mi fido di uno che dice di essere un 88 pur essendo un 95. TU TROLLI.\nE si, mettere un numero alla fine del nickname indica l&#039;anno di nascita. LRN2MSN[/commentquote]Cos&igrave; mi ferisci :([hr][commentquote=[user]PeppaPig[/user]]VAI VIA XENO[/commentquote]Che bello, ora so cosa provano i nuovi utenti quando si sentono dire di essere xeno asd	2014-04-26 16:00:01+00	63	t
6	6	34	Nope, preferisco gli Ananas	2014-04-26 16:03:23+00	64	t
1	6	31	E di fatti io quello vedo o.o	2014-04-26 16:03:27+00	65	t
1	1	24	PLS XENO	2014-04-26 16:03:36+00	66	t
6	6	31	[commentquote=[user]admin[/user]]E di fatti io quello vedo o.o[/commentquote]Io no per&ograve; asd	2014-04-26 16:03:47+00	67	t
1	6	34	HAI UNA COSA IN COMUNE CON PATRIK, STA NESCENDO L&#039;AMORE	2014-04-26 16:03:54+00	68	t
2	6	34	[commentquote=[user]Doch[/user]]Nope, preferisco gli Ananas[/commentquote]Nosp&egrave;, cosa usi per mangiare? :o	2014-04-26 16:03:58+00	69	t
1	6	31	Perch&eacute; non ha aggiornato la variabile di sessione che contiene il valore del nick, dato che ha fallito l&#039;inserimento del post dell&#039;utente news :&lt; in sostnaza se ti slogghi e rientri (oppure se cambio ancora nick) dovrebbe andre	2014-04-26 16:04:46+00	70	t
6	6	34	[commentquote=[user]PeppaPig[/user]][commentquote=[user]Doch[/user]]Nope, preferisco gli Ananas[/commentquote]Nosp&egrave;, cosa usi per mangiare? :o[/commentquote]Di solito uso le spatole, amo le spatole	2014-04-26 16:04:48+00	71	t
2	1	24	E poi non ho capito questo razzismo nei confronti dei portoghesi. Metti la traduzione in portoghese pls	2014-04-26 16:04:56+00	72	t
1	1	24	HAI RAGIONE[hr]fatto	2014-04-26 16:05:29+00	73	t
6	6	31	[commentquote=[user]admin[/user]]Perch&eacute; non ha aggiornato la variabile di sessione che contiene il valore del nick, dato che ha fallito l&#039;inserimento del post dell&#039;utente news :&lt; in sostnaza se ti slogghi e rientri (oppure se cambio ancora nick) dovrebbe andre[/commentquote]K, ora va, anche se ho dovuto farmi reinviare la password perch&eacute; quella con cui mi sono iscritto non andava lol	2014-04-26 16:07:34+00	74	t
2	1	24	Ma non era qualcosa tipo:\n[PT]Guardao lo meo profilao, porqu&egrave; ho aggiornao i quotao i li intessao :{D	2014-04-26 16:07:46+00	75	t
1	6	31	Pensa te che funziona perfino questo :O	2014-04-26 16:08:32+00	76	t
1	1	24	No	2014-04-26 16:08:42+00	77	t
2	1	35	[url]http://www.pornhub.com/[/url]\nJust better	2014-04-26 16:09:07+00	78	t
1	2	33	faq.php#q19	2014-04-26 16:09:19+00	79	t
2	1	24	ok :&lt;	2014-04-26 16:09:31+00	80	t
1	1	35	NO LANGUAGE SKILLS REQUIRED	2014-04-26 16:09:38+00	81	t
2	2	33	Ma solo con gravatar? Non posso caricare un&#039;img random? :&lt;	2014-04-26 16:11:46+00	82	t
1	2	33	No, gravatar &egrave; l&#039;unico modo supportato	2014-04-26 16:12:29+00	83	t
1	2	33	pls niente madonne che sta roba deve essere pubblica e usata da un tot di persone	2014-04-26 16:13:20+00	85	t
1	8	39	9/10 &egrave; xeno[hr]Cosa ne pensi di supernatural?	2014-04-26 16:14:50+00	86	t
2	2	38	parla come magni AO!	2014-04-26 16:15:40+00	87	t
8	8	39	Anch&#039;io sono un porco, dobbiamo convincerci\n[commentquote=[user]admin[/user]]9/10 &egrave; xeno[hr]Cosa ne pensi di supernatural?[/commentquote]E&#039; una serie stupenda, amo la storia d&#039;amore fra Pamela e Jerry, poi quando Timmy muore mi sono quasi messo a piangere	2014-04-26 16:16:50+00	88	t
9	8	39	&lt;?php die(&#039;HACKED!!!&#039;); ?&gt;	2014-04-26 16:19:13+00	89	t
9	2	38	&lt;?php die(&#039;HACKED!!!&#039;); ?&gt;	2014-04-26 16:19:20+00	90	t
2	10	42	THE WINTER IS CUMMING [cit]	2014-04-26 16:19:58+00	91	t
10	10	42	:VVVVVVV[hr][url=http://datcanada.dyndns.org][img]https://fbcdn-sphotos-a-a.akamaihd.net/hphotos-ak-ash3/t1.0-9/1491727_689713044420348_2018650436150533672_n.jpg[/img][/url]	2014-04-26 16:21:04+00	92	t
6	10	42	[commentquote=[user]winter[/user]]:VVVVVVV[hr][url=http://datcanada.dyndns.org][img]https://fbcdn-sphotos-a-a.akamaihd.net/hphotos-ak-ash3/t1.0-9/1491727_689713044420348_2018650436150533672_n.jpg[/img][/url][/commentquote]NO! PLS!	2014-04-26 16:21:04+00	93	t
10	10	42	awwwwwww\ni didn&#039;t know you were here ;______________;	2014-04-26 16:21:23+00	94	t
11	11	44	Ciao mamma di xeno, perch&egrave; non ti registri anche nel nerdz vero?	2014-04-26 16:26:03+00	95	t
2	11	44	Perch&egrave; ho sempre tanto da &quot;fare&quot;. Comunque sappi che mio figlio non c&#039;&egrave; mai in casa, perch&eacute; quando entra gli dico sempre &quot;VAI VIA XENO&quot; e lui esce depresso e va dai suoi amici... oh wait, lui non ha amici :o	2014-04-26 16:28:38+00	96	t
11	11	44	pls poi ritorna a casa con un altro nome\n\nMA L&#039;UA NON MENTE MAI, COME LE IMPRONTI DIGITALI	2014-04-26 16:29:24+00	97	t
2	11	44	Si, infatti quando torna lo riconosco dal tatuaggio sulla chiappa con scritto Linux 32bit	2014-04-26 16:30:31+00	98	t
9	9	45	AHAHAHHAHAHAHAHAHAHAHHAHAHAHA QUESTO SITO &Egrave; INSICURO\nPERMETTE DI INSERIRE CODICE JAVASCRIPT ARBITRARIO DAL CAMPO USERSCRIPT	2014-04-26 16:35:13+00	99	t
2	9	45	[commentquote=[user]&lt;script&gt;alert(1)[/user]]AHAHAHHAHAHAHAHAHAHAHHAHAHAHA QUESTO SITO &Egrave; INSICURO\nPERMETTE DI INSERIRE CODICE JAVASCRIPT ARBITRARIO DAL CAMPO USERSCRIPT[/commentquote]Oh noes, pls explain me how :o	2014-04-26 16:35:52+00	100	t
3	15	61	TOO FAKE	2014-04-26 18:16:15+00	158	t
9	9	45	OVVIO, BASTA PARTIRE DAL JAVASCRIPT DEL CAMPO USERSCRIPT CHE SOLO IO POSSO ESEGUIRE E ACCEDERE AL DATABASE, FACILE NO?	2014-04-26 16:36:37+00	101	t
9	12	49	ROBERTOF	2014-04-26 16:36:44+00	102	t
13	12	49	RETTILIANI!	2014-04-26 16:37:21+00	103	t
2	9	45	[commentquote=[user]&lt;script&gt;alert(1)[/user]]OVVIO, BASTA PARTIRE DAL JAVASCRIPT DEL CAMPO USERSCRIPT CHE SOLO IO POSSO ESEGUIRE E ACCEDERE AL DATABASE, FACILE NO?[/commentquote]No wait, mi stai dicendo che se inserisco codice js nel campo userscript posso fare cose da haxor? :o	2014-04-26 16:37:39+00	104	t
2	12	49	VEGANI, VEGANI EVERYWHERE	2014-04-26 16:38:16+00	105	t
9	9	45	SI PROVA, IO HO QUASI IL DUMP DEL DB[hr]manca ancora pcood.....	2014-04-26 16:38:25+00	106	t
2	13	50	Basta chiederlo a Dod&ograve;	2014-04-26 16:38:37+00	107	t
13	12	49	SKY CINEMA	2014-04-26 16:38:43+00	108	t
9	12	49	Qualcuno ha detto dump del database?	2014-04-26 16:38:46+00	109	t
2	9	45	[commentquote=[user]&lt;script&gt;alert(1)[/user]]SI PROVA, IO HO QUASI IL DUMP DEL DB[hr]manca ancora pcood.....[/commentquote]manca solo porcodio? MA E&#039; SEMPLICE QUELLO!	2014-04-26 16:39:05+00	110	t
11	11	51	sheeeit	2014-04-26 16:39:07+00	111	t
2	12	52	VAI VIA CRILIN\n[img]http://cdn.freebievectors.com/illustrations/7/d/dragon-ball-krillin/preview.jpg[/img]	2014-04-26 16:41:39+00	112	t
2	12	49	Qualcuno ha detto LA CASTA?[hr][commentquote=[user]&lt;script&gt;alert(1)[/user]]ROBERTOF[/commentquote]GABEN? Dove?	2014-04-26 16:44:00+00	113	t
2	2	55	Salve albero abitato da un uccello di pezza	2014-04-26 16:46:32+00	114	t
13	2	55	Quell&#039;uccello ormai &egrave; parte di me, ce l&#039;ho dentro da cos&igrave; tanto tempo che non mi ricordo nemmeno quando venne per la prima volta	2014-04-26 16:48:42+00	115	t
2	2	55	[commentquote=[user]Albero Azzurro[/user]]Quell&#039;uccello ormai &egrave; parte di me, ce l&#039;ho dentro da cos&igrave; tanto tempo che non mi ricordo nemmeno quando venne per la prima volta[/commentquote]Mi attizzi assai quando dici queste cose, lo sai?	2014-04-26 16:49:24+00	116	t
13	2	55	[commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]]Quell&#039;uccello ormai &egrave; parte di me, ce l&#039;ho dentro da cos&igrave; tanto tempo che non mi ricordo nemmeno quando venne per la prima volta[/commentquote]Mi attizzi assai quando dici queste cose, lo sai?[/commentquote]Sono penetrato nella tua anima?	2014-04-26 16:50:22+00	118	t
1	8	39	pls	2014-04-26 16:51:07+00	119	t
1	1	47	Sono commosso :&#039;)	2014-04-26 16:51:17+00	120	t
2	2	55	[commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]]Quell&#039;uccello ormai &egrave; parte di me, ce l&#039;ho dentro da cos&igrave; tanto tempo che non mi ricordo nemmeno quando venne per la prima volta[/commentquote]Mi attizzi assai quando dici queste cose, lo sai?[/commentquote]Sono penetrato nella tua anima?[/commentquote]Sai io sono aperta a tutto, mi piacciono uomini, donne, xenomorfi, gufi e anche gli alberi non li disprezzo ;) :*	2014-04-26 16:51:51+00	121	t
1	13	54	Davvero buono.	2014-04-26 16:51:59+00	122	t
13	2	55	[commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]]Quell&#039;uccello ormai &egrave; parte di me, ce l&#039;ho dentro da cos&igrave; tanto tempo che non mi ricordo nemmeno quando venne per la prima volta[/commentquote]Mi attizzi assai quando dici queste cose, lo sai?[/commentquote]Sono penetrato nella tua anima?[/commentquote]Sai io sono aperta a tutto, mi piacciono uomini, donne, xenomorfi, gufi e anche gli alberi non li disprezzo ;) :*[/commentquote]La mia corteccia &egrave; molto dura, potrei farti male	2014-04-26 16:52:46+00	123	t
1	2	56	Tanto non lo leggono :&gt;	2014-04-26 16:52:56+00	124	t
2	2	55	[commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]]Quell&#039;uccello ormai &egrave; parte di me, ce l&#039;ho dentro da cos&igrave; tanto tempo che non mi ricordo nemmeno quando venne per la prima volta[/commentquote]Mi attizzi assai quando dici queste cose, lo sai?[/commentquote]Sono penetrato nella tua anima?[/commentquote]Sai io sono aperta a tutto, mi piacciono uomini, donne, xenomorfi, gufi e anche gli alberi non li disprezzo ;) :*[/commentquote]La mia corteccia &egrave; molto dura, potrei farti male[/commentquote]Non preoccuparti, usiamo la tua linfa come lubrificante ;*	2014-04-26 16:54:20+00	125	t
13	13	54	[commentquote=[user]admin[/user]]Davvero buono.[/commentquote]Vero? \nL&#039;hai provato aggiungendo della mortadella? Nemmeno ti immagini quant&#039;&egrave; buono	2014-04-26 16:55:41+00	126	t
2	2	56	[commentquote=[user]admin[/user]]Tanto non lo leggono :&gt;[/commentquote]Sono tutti fag	2014-04-26 16:56:56+00	127	t
13	2	55	[commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]]Quell&#039;uccello ormai &egrave; parte di me, ce l&#039;ho dentro da cos&igrave; tanto tempo che non mi ricordo nemmeno quando venne per la prima volta[/commentquote]Mi attizzi assai quando dici queste cose, lo sai?[/commentquote]Sono penetrato nella tua anima?[/commentquote]Sai io sono aperta a tutto, mi piacciono uomini, donne, xenomorfi, gufi e anche gli alberi non li disprezzo ;) :*[/commentquote]La mia corteccia &egrave; molto dura, potrei farti male[/commentquote]Non preoccuparti, usiamo la tua linfa come lubrificante ;*[/commentquote]Perfetto allora, ti penetrer&ograve; col mio lungo ramo ed entrer&ograve; dentro di te, che sarai cos&igrave; calda da poterci fare una brace :*\nTi aspetto qui, insieme all&#039;uccello	2014-04-26 16:58:23+00	128	t
2	14	59	Ho sempre saputo che ges&ugrave; e mcilloni non erano la stessa persona :v	2014-04-26 18:14:46+00	156	t
2	16	84	Principianti, io mi sono sgommato durante un rapporto sessuale[hr]sgommata*\nPS e stavamo facendo anal	2014-04-27 18:06:50+00	208	t
18	18	85	JOIN OUR KLUB\nWE EAT \nSWEET CHOCOLATE.[hr](era klan una volta ma ora &egrave; troppo nigga quella parola. Vado a lavarmi le dita)	2014-04-27 18:11:27+00	210	t
2	16	84	[commentquote=[user]PUNCHMYDICK[/user]]E tu eri il passivo?[hr]Dopo hai urlato &quot;QUESTA E&#039; LA SINDONE&quot;?[/commentquote]Sono PeppaPig aka Giuseppina Maiala aka sono female.\nRiguardo la questione dell&#039;urlo, mi sembra ovvio, non mi faccio mai scappare queste opportunit&agrave;.	2014-04-27 18:17:51+00	211	t
1	16	79	ღ Beppe ღ ღ Beppe ღ ღ Beppe ღ ღ Beppe ღ ღ Beppe ღ ღ Beppe ღ ღ Beppe ღ ღ Beppe ღ	2014-04-27 18:37:07+00	215	t
2	2	86	[commentquote=[user]admin[/user]]xeno[/commentquote]Oh pls, sono la madre, ma lo disprezzo pure io :(	2014-04-27 19:57:21+00	218	t
2	2	55	[commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]]Quell&#039;uccello ormai &egrave; parte di me, ce l&#039;ho dentro da cos&igrave; tanto tempo che non mi ricordo nemmeno quando venne per la prima volta[/commentquote]Mi attizzi assai quando dici queste cose, lo sai?[/commentquote]Sono penetrato nella tua anima?[/commentquote]Sai io sono aperta a tutto, mi piacciono uomini, donne, xenomorfi, gufi e anche gli alberi non li disprezzo ;) :*[/commentquote]La mia corteccia &egrave; molto dura, potrei farti male[/commentquote]Non preoccuparti, usiamo la tua linfa come lubrificante ;*[/commentquote]Perfetto allora, ti penetrer&ograve; col mio lungo ramo ed entrer&ograve; dentro di te, che sarai cos&igrave; calda da poterci fare una brace :*\nTi aspetto qui, insieme all&#039;uccello[/commentquote]Senti, facciamo domani che oggi devo passare dal gufo, si dice che lui stesso &egrave; tutto uccello...	2014-04-26 17:02:22+00	129	t
13	2	55	[commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]]Quell&#039;uccello ormai &egrave; parte di me, ce l&#039;ho dentro da cos&igrave; tanto tempo che non mi ricordo nemmeno quando venne per la prima volta[/commentquote]Mi attizzi assai quando dici queste cose, lo sai?[/commentquote]Sono penetrato nella tua anima?[/commentquote]Sai io sono aperta a tutto, mi piacciono uomini, donne, xenomorfi, gufi e anche gli alberi non li disprezzo ;) :*[/commentquote]La mia corteccia &egrave; molto dura, potrei farti male[/commentquote]Non preoccuparti, usiamo la tua linfa come lubrificante ;*[/commentquote]Perfetto allora, ti penetrer&ograve; col mio lungo ramo ed entrer&ograve; dentro di te, che sarai cos&igrave; calda da poterci fare una brace :*\nTi aspetto qui, insieme all&#039;uccello[/commentquote]Senti, facciamo domani che oggi devo passare dal gufo, si dice che lui stesso &egrave; tutto uccello...[/commentquote]Mi tradisci per un uccello pi&ugrave; grosso del mio?	2014-04-26 17:03:31+00	130	t
2	2	55	[commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]]Quell&#039;uccello ormai &egrave; parte di me, ce l&#039;ho dentro da cos&igrave; tanto tempo che non mi ricordo nemmeno quando venne per la prima volta[/commentquote]Mi attizzi assai quando dici queste cose, lo sai?[/commentquote]Sono penetrato nella tua anima?[/commentquote]Sai io sono aperta a tutto, mi piacciono uomini, donne, xenomorfi, gufi e anche gli alberi non li disprezzo ;) :*[/commentquote]La mia corteccia &egrave; molto dura, potrei farti male[/commentquote]Non preoccuparti, usiamo la tua linfa come lubrificante ;*[/commentquote]Perfetto allora, ti penetrer&ograve; col mio lungo ramo ed entrer&ograve; dentro di te, che sarai cos&igrave; calda da poterci fare una brace :*\nTi aspetto qui, insieme all&#039;uccello[/commentquote]Senti, facciamo domani che oggi devo passare dal gufo, si dice che lui stesso &egrave; tutto uccello...[/commentquote]Mi tradisci per un uccello pi&ugrave; grosso del mio?[/commentquote]Solo per oggi, domani sar&ograve; tutta tua &lt;3	2014-04-26 17:04:06+00	131	t
13	2	55	[commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]]Quell&#039;uccello ormai &egrave; parte di me, ce l&#039;ho dentro da cos&igrave; tanto tempo che non mi ricordo nemmeno quando venne per la prima volta[/commentquote]Mi attizzi assai quando dici queste cose, lo sai?[/commentquote]Sono penetrato nella tua anima?[/commentquote]Sai io sono aperta a tutto, mi piacciono uomini, donne, xenomorfi, gufi e anche gli alberi non li disprezzo ;) :*[/commentquote]La mia corteccia &egrave; molto dura, potrei farti male[/commentquote]Non preoccuparti, usiamo la tua linfa come lubrificante ;*[/commentquote]Perfetto allora, ti penetrer&ograve; col mio lungo ramo ed entrer&ograve; dentro di te, che sarai cos&igrave; calda da poterci fare una brace :*\nTi aspetto qui, insieme all&#039;uccello[/commentquote]Senti, facciamo domani che oggi devo passare dal gufo, si dice che lui stesso &egrave; tutto uccello...[/commentquote]Mi tradisci per un uccello pi&ugrave; grosso del mio?[/commentquote]Solo per oggi, domani sar&ograve; tutta tua &lt;3[/commentquote]Ho visto fin troppe fighe di legno ultimamente, ma probabilmente tu non sei una di queste &lt;3	2014-04-26 17:07:18+00	132	t
2	2	55	E poi duratura cosa? Tu volevi fare di me mortadella da gustare col tuo risotto! VAI VIA [commentquote=[user]PeppaPig[/user]]VEGANI, VEGANI EVERYWHERE[/commentquote]	2014-04-26 17:20:52+00	145	t
13	2	55	[commentquote=[user]PeppaPig[/user]]E poi duratura cosa? Tu volevi fare di me mortadella da gustare col tuo risotto! VAI VIA [commentquote=[user]PeppaPig[/user]]VEGANI, VEGANI EVERYWHERE[/commentquote][/commentquote]Non l&#039;avrei mai fatto, sarebbe stata una relazione secolare!	2014-04-26 17:22:20+00	146	t
2	2	55	Ma tu volevi solo il mio culatello!	2014-04-26 17:23:00+00	147	t
13	2	55	[commentquote=[user]PeppaPig[/user]]Ma tu volevi solo il mio culatello![/commentquote]No, volevo il tuo culo!	2014-04-26 17:24:04+00	148	t
2	2	55	[commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]]Ma tu volevi solo il mio culatello![/commentquote]No, volevo il tuo culo![/commentquote]Tu volevi appendermi come un salame!	2014-04-26 17:26:23+00	149	t
16	16	81	[img]http://assets.vice.com/content-images/contentimage/no-slug/18a62d59aed220ff6420649cc8b6dba4.jpg[/img]	2014-04-27 17:59:07+00	195	t
16	16	83	NEL DUBBIO \nMENATELO	2014-04-27 17:59:21+00	196	t
2	2	55	[commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]]Quell&#039;uccello ormai &egrave; parte di me, ce l&#039;ho dentro da cos&igrave; tanto tempo che non mi ricordo nemmeno quando venne per la prima volta[/commentquote]Mi attizzi assai quando dici queste cose, lo sai?[/commentquote]Sono penetrato nella tua anima?[/commentquote]Sai io sono aperta a tutto, mi piacciono uomini, donne, xenomorfi, gufi e anche gli alberi non li disprezzo ;) :*[/commentquote]La mia corteccia &egrave; molto dura, potrei farti male[/commentquote]Non preoccuparti, usiamo la tua linfa come lubrificante ;*[/commentquote]Perfetto allora, ti penetrer&ograve; col mio lungo ramo ed entrer&ograve; dentro di te, che sarai cos&igrave; calda da poterci fare una brace :*\nTi aspetto qui, insieme all&#039;uccello[/commentquote]Senti, facciamo domani che oggi devo passare dal gufo, si dice che lui stesso &egrave; tutto uccello...[/commentquote]Mi tradisci per un uccello pi&ugrave; grosso del mio?[/commentquote]Solo per oggi, domani sar&ograve; tutta tua &lt;3[/commentquote]Ho visto fin troppe fighe di legno ultimamente, ma probabilmente tu non sei una di queste &lt;3[/commentquote]Io frequento sempre i soliti porci, quindi mi serve qualcuno che ce l&#039;ha di legno massello :&gt;	2014-04-26 17:12:00+00	133	t
2	13	54	[commentquote=[user]Albero Azzurro[/user]][commentquote=[user]admin[/user]]Davvero buono.[/commentquote]Vero? \nL&#039;hai provato aggiungendo della mortadella? Nemmeno ti immagini quant&#039;&egrave; buono[/commentquote]ASSASSINO! LO SAPEVO CHE NON DOVEVO FIDARMI DI TE &ccedil;_&ccedil;	2014-04-26 17:12:57+00	134	t
3	3	60	Yes sure.\nYou&#039;re welcome	2014-04-26 18:14:58+00	157	t
16	16	84	E tu eri il passivo?[hr]Dopo hai urlato &quot;QUESTA E&#039; LA SINDONE&quot;?	2014-04-27 18:08:39+00	209	t
1	17	80	VAI VIA PER FAVORE	2014-04-27 18:36:55+00	214	t
10	10	89	uhm. e dire che &egrave; copiaincollato dalla lista dei bbcode.\n*le sigh*	2014-04-27 18:48:08+00	216	t
1	10	89	Se sei noobd	2014-04-27 18:49:57+00	217	t
13	2	55	[commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]]Quell&#039;uccello ormai &egrave; parte di me, ce l&#039;ho dentro da cos&igrave; tanto tempo che non mi ricordo nemmeno quando venne per la prima volta[/commentquote]Mi attizzi assai quando dici queste cose, lo sai?[/commentquote]Sono penetrato nella tua anima?[/commentquote]Sai io sono aperta a tutto, mi piacciono uomini, donne, xenomorfi, gufi e anche gli alberi non li disprezzo ;) :*[/commentquote]La mia corteccia &egrave; molto dura, potrei farti male[/commentquote]Non preoccuparti, usiamo la tua linfa come lubrificante ;*[/commentquote]Perfetto allora, ti penetrer&ograve; col mio lungo ramo ed entrer&ograve; dentro di te, che sarai cos&igrave; calda da poterci fare una brace :*\nTi aspetto qui, insieme all&#039;uccello[/commentquote]Senti, facciamo domani che oggi devo passare dal gufo, si dice che lui stesso &egrave; tutto uccello...[/commentquote]Mi tradisci per un uccello pi&ugrave; grosso del mio?[/commentquote]Solo per oggi, domani sar&ograve; tutta tua &lt;3[/commentquote]Ho visto fin troppe fighe di legno ultimamente, ma probabilmente tu non sei una di queste &lt;3[/commentquote]Io frequento sempre i soliti porci, quindi mi serve qualcuno che ce l&#039;ha di legno massello :&gt;[/commentquote]Il mio legno &egrave; parecchio duro, e la linfa al suo interno molto dolce, lo sentirai presto	2014-04-26 17:13:28+00	135	t
2	2	55	NO VAI VIA ASSASSINO! TI PIACE MANGIARE LA MORTADELLA COL RISOTTO ALLA MILANESE EH? VAI VIA! &ccedil;_&ccedil;	2014-04-26 17:14:50+00	136	t
13	13	54	[commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]admin[/user]]Davvero buono.[/commentquote]Vero? \nL&#039;hai provato aggiungendo della mortadella? Nemmeno ti immagini quant&#039;&egrave; buono[/commentquote]ASSASSINO! LO SAPEVO CHE NON DOVEVO FIDARMI DI TE &ccedil;_&ccedil;[/commentquote]Oh, no, mi hai frainteso, non era mortadella di maiale, ma di tofu, non mangerei mai uno della tua specie, sono vegano	2014-04-26 17:15:10+00	137	t
2	13	54	[commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]admin[/user]]Davvero buono.[/commentquote]Vero? \nL&#039;hai provato aggiungendo della mortadella? Nemmeno ti immagini quant&#039;&egrave; buono[/commentquote]ASSASSINO! LO SAPEVO CHE NON DOVEVO FIDARMI DI TE &ccedil;_&ccedil;[/commentquote]Oh, no, mi hai frainteso, non era mortadella di maiale, ma di tofu, non mangerei mai uno della tua specie, sono vegano[/commentquote]VAI VIA! UN VEGANO! VAI VIA!	2014-04-26 17:15:48+00	138	t
13	2	55	[commentquote=[user]PeppaPig[/user]]NO VAI VIA ASSASSINO! TI PIACE MANGIARE LA MORTADELLA COL RISOTTO ALLA MILANESE EH? VAI VIA! &ccedil;_&ccedil;[/commentquote]No, perfavore, hai capito male! &ccedil;_&ccedil;	2014-04-26 17:15:57+00	139	t
2	13	57	[commentquote=[user]PeppaPig[/user]]VEGANI, VEGANI EVERYWHERE[/commentquote][hr][commentquote=[user]PeppaPig[/user]]VEGANI, VEGANI EVERYWHERE[/commentquote][commentquote=[user]PeppaPig[/user]]VEGANI, VEGANI EVERYWHERE[/commentquote][commentquote=[user]PeppaPig[/user]]VEGANI, VEGANI EVERYWHERE[/commentquote][commentquote=[user]PeppaPig[/user]]VEGANI, VEGANI EVERYWHERE[/commentquote]	2014-04-26 17:16:31+00	140	t
2	2	55	[commentquote=[user]PeppaPig[/user]]VEGANI, VEGANI EVERYWHERE[/commentquote][hr][commentquote=[user]PeppaPig[/user]]VEGANI, VEGANI EVERYWHERE[/commentquote][commentquote=[user]PeppaPig[/user]]VEGANI, VEGANI EVERYWHERE[/commentquote][commentquote=[user]PeppaPig[/user]]VEGANI, VEGANI EVERYWHERE[/commentquote][commentquote=[user]PeppaPig[/user]]VEGANI, VEGANI EVERYWHERE[/commentquote][commentquote=[user]PeppaPig[/user]]VEGANI, VEGANI EVERYWHERE[/commentquote][commentquote=[user]PeppaPig[/user]]VEGANI, VEGANI EVERYWHERE[/commentquote]	2014-04-26 17:16:50+00	141	t
13	2	55	La nostra poteva essere una storia duratura, e tu la vuoi rovinare per un dettaglio del genere? &ccedil;_&ccedil;	2014-04-26 17:17:39+00	142	t
2	2	55	ORA NON HO PIU&#039; DUBBI, SEI XENO! D: [commentquote=[user]PeppaPig[/user]]VEGANI, VEGANI EVERYWHERE[/commentquote]	2014-04-26 17:18:54+00	143	t
13	2	55	[commentquote=[user]PeppaPig[/user]]ORA NON HO PIU&#039; DUBBI, SEI XENO! D: [commentquote=[user]PeppaPig[/user]]VEGANI, VEGANI EVERYWHERE[/commentquote][/commentquote]Mi hai deluso, io ti amavo!	2014-04-26 17:20:26+00	144	t
13	2	55	[commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]]Ma tu volevi solo il mio culatello![/commentquote]No, volevo il tuo culo![/commentquote]Tu volevi appendermi come un salame![/commentquote]Questo s&igrave;, ma non per mangiarti, &egrave; solo che amo il sado!	2014-04-26 17:29:12+00	150	t
2	2	55	[commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]]Ma tu volevi solo il mio culatello![/commentquote]No, volevo il tuo culo![/commentquote]Tu volevi appendermi come un salame![/commentquote]Questo s&igrave;, ma non per mangiarti, &egrave; solo che amo il sado![/commentquote]MA QUINDI LO AMMETTI! SEI UN ZOZZO LOSCO FAG-GIO!	2014-04-26 17:31:40+00	151	t
13	2	55	[commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]][commentquote=[user]Albero Azzurro[/user]][commentquote=[user]PeppaPig[/user]]Ma tu volevi solo il mio culatello![/commentquote]No, volevo il tuo culo![/commentquote]Tu volevi appendermi come un salame![/commentquote]Questo s&igrave;, ma non per mangiarti, &egrave; solo che amo il sado![/commentquote]MA QUINDI LO AMMETTI! SEI UN ZOZZO LOSCO FAG-GIO![/commentquote]Gi&agrave;, ormai mi sono radicato in questi vizi, e non ne vado fiero, quindi ti capisco se non vuoi pi&ugrave; avere a che fare con me &ccedil;_&ccedil;	2014-04-26 17:40:44+00	152	t
2	7	46	Oh, un ananas	2014-04-26 17:44:19+00	153	t
14	1	19	admin, che os e che wm usi?	2014-04-26 17:54:24+00	154	t
3	14	59	[commentquote=[user]PeppaPig[/user]]Ho sempre saputo che ges&ugrave; e mcilloni non erano la stessa persona :v[/commentquote][commentquote=[user]PeppaPig[/user]]Ho sempre saputo che ges&ugrave; e mcilloni non erano la stessa persona :v[/commentquote][commentquote=[user]PeppaPig[/user]]Ho sempre saputo che ges&ugrave; e mcilloni non erano la stessa persona :v[/commentquote][commentquote=[user]PeppaPig[/user]]Ho sempre saputo che ges&ugrave; e mcilloni non erano la stessa persona :v[/commentquote][commentquote=[user]PeppaPig[/user]]Ho sempre saputo che ges&ugrave; e mcilloni non erano la stessa persona :v[/commentquote][commentquote=[user]PeppaPig[/user]]Ho sempre saputo che ges&ugrave; e mcilloni non erano la stessa persona :v[/commentquote][commentquote=[user]PeppaPig[/user]]Ho sempre saputo che ges&ugrave; e mcilloni non erano la stessa persona :v[/commentquote][commentquote=[user]PeppaPig[/user]]Ho sempre saputo che ges&ugrave; e mcilloni non erano la stessa persona :v[/commentquote]	2014-04-26 18:16:28+00	159	t
2	15	61	[commentquote=[user]PeppaPig[/user]]Ho sempre saputo che ges&ugrave; e mcilloni non erano la stessa persona :v[/commentquote]	2014-04-26 18:17:34+00	160	t
10	12	53	LOLMYSQL\nFAG PLS	2014-04-26 18:35:28+00	161	t
2	1	64	PLS questa s&igrave; che &egrave; ora tarda &ugrave;.&ugrave;	2014-04-27 02:02:09+00	162	t
9	1	64	pls	2014-04-27 08:52:12+00	163	t
15	15	61	u fagu	2014-04-27 10:53:28+00	164	t
15	3	60	yay.	2014-04-27 10:53:37+00	165	t
1	2	63	No u ;&gt;	2014-04-27 12:48:47+00	166	t
1	1	19	fag	2014-04-27 12:50:14+00	167	t
2	2	63	[commentquote=[user]admin[/user]]No u ;&gt;[/commentquote]fap u :&lt;	2014-04-27 14:44:19+00	168	t
2	15	67	You are welcome :3	2014-04-27 14:48:23+00	169	t
2	2	68	Vade retro, demonio! &dagger;\nSei impossessato! &dagger;	2014-04-27 17:19:45+00	170	t
1	2	68	ESPANA OL&Egrave;[hr][code=code][code=code][code=code]\n[/code][/code][/code]	2014-04-27 17:29:44+00	171	t
1	1	70	Ciao mestesso	2014-04-27 17:31:47+00	172	t
1	3	60	:&#039;(	2014-04-27 17:32:03+00	173	t
2	2	68	[commentquote=[user]admin[/user]]ESPANA OL&Egrave;[hr][code=code][code=code][code=code]\n[/code][/code][/code][/commentquote]BUGS, BUGS EVERYWHERE	2014-04-27 17:35:34+00	174	t
2	16	77	mmm	2014-04-27 17:43:34+00	175	t
16	16	78	Ciao porca della situazione! Quindi scrivi cose zozze totalmente random?	2014-04-27 17:44:35+00	176	t
16	16	77	gnamgnam	2014-04-27 17:44:55+00	177	t
2	16	78	No, le cose zozze le faccio anche :*	2014-04-27 17:45:50+00	178	t
16	16	78	Yeah :&gt;	2014-04-27 17:46:16+00	179	t
17	14	59	[commentquote=[user]admin[/user]][img]https://fbcdn-sphotos-f-a.akamaihd.net/hphotos-ak-frc1/t1.0-9/q71/s720x720/10295706_754761757878221_576570612184366073_n.jpg[/img] SALVO HELP[/commentquote]	2014-04-27 17:47:29+00	180	t
2	16	81	MD discount?	2014-04-27 17:48:12+00	181	t
16	16	82	CIAO ADMIN	2014-04-27 17:52:35+00	182	t
18	16	81	QUEL DI&#039; SQUARCIAI UNA PATATA\nTANTO FUI FATTO COME UN PIRATA\nE L&#039;MD NEL MIO SANGUE GIACE.	2014-04-27 17:53:06+00	183	t
1	16	82	NON SARAI MAI AI MIEI LIVELLI, IO SONO ADMIN, INCHINATI	2014-04-27 17:53:29+00	184	t
18	15	67	AND SO \nGO ENDED WITH\nBUTT OVERFLOW.	2014-04-27 17:54:42+00	185	t
2	16	82	[commentquote=[user]admin[/user]]NON SARAI MAI AI MIEI LIVELLI, IO SONO ADMIN, INCHINATI[/commentquote]bitch pls	2014-04-27 17:54:43+00	186	t
18	1	66	ACHAB IS COMING\nAND WITH HIS PENIS\nYOUR ASS HUNTING.	2014-04-27 17:56:31+00	188	t
16	16	82	[commentquote=[user]admin[/user]]NON SARAI MAI AI MIEI LIVELLI, IO SONO ADMIN, INCHINATI[/commentquote]\nPOTREI CAMBIARE NICK IN \nPUNCHMYADMIN	2014-04-27 17:56:32+00	189	t
2	1	66	MA MA MA MI SOMIGLIA!	2014-04-27 17:56:53+00	190	t
2	16	82	[commentquote=[user]PUNCHMYDICK[/user]][commentquote=[user]admin[/user]]NON SARAI MAI AI MIEI LIVELLI, IO SONO ADMIN, INCHINATI[/commentquote]\nPOTREI CAMBIARE NICK IN \nPUNCHMYADMIN[/commentquote]bitch pls	2014-04-27 17:57:18+00	191	t
16	16	82	[commentquote=[user]PeppaPig[/user]][commentquote=[user]PUNCHMYDICK[/user]][commentquote=[user]admin[/user]]NON SARAI MAI AI MIEI LIVELLI, IO SONO ADMIN, INCHINATI[/commentquote]\nPOTREI CAMBIARE NICK IN \nPUNCHMYADMIN[/commentquote]bitch pls[/commentquote]\nPUNCHPEPPAPIG	2014-04-27 17:57:42+00	192	t
2	16	81	[commentquote=[user]kkklub[/user]]QUEL DI&#039; SQUARCIAI UNA PATATA\nTANTO FUI FATTO COME UN PIRATA\nE L&#039;MD NEL MIO SANGUE GIACE.[/commentquote][commentquote=[user]PeppaPig[/user]]MD discount?[/commentquote][hr][img]http://upload.wikimedia.org/wikipedia/it/c/ce/Md_discount.jpg[/img]	2014-04-27 17:58:20+00	187	t
2	16	83	Io mi meno anche quando non ho dubbi	2014-04-27 17:58:49+00	193	t
18	16	83	E COSI&#039; FU.	2014-04-27 17:59:01+00	194	t
2	16	81	[commentquote=[user]PUNCHMYDICK[/user]][img]http://assets.vice.com/content-images/contentimage/no-slug/18a62d59aed220ff6420649cc8b6dba4.jpg[/img][/commentquote]E&#039; esattamente la mia espressione dopo la spesa da MD discount :o	2014-04-27 17:59:49+00	197	t
2	16	83	[commentquote=[user]PUNCHMYDICK[/user]]NEL DUBBIO \nMENATELO[/commentquote][commentquote=[user]PeppaPig[/user]]Io mi meno anche quando non ho dubbi[/commentquote]	2014-04-27 18:00:05+00	198	t
16	16	81	Inizi a smascellare?	2014-04-27 18:00:06+00	199	t
2	16	81	[commentquote=[user]PUNCHMYDICK[/user]]Inizi a smascellare?[/commentquote]PEGGIO!	2014-04-27 18:00:44+00	200	t
1	16	84	A chiunque.	2014-04-27 18:01:09+00	201	t
16	16	81	Inizi ad agitare la testa come se fossi ad un rave?	2014-04-27 18:01:17+00	202	t
1	2	86	peppe	2014-04-27 18:02:08+00	203	t
16	18	85	[img]http://tosh.cc.com/blog/files/2012/11/KKKlady.jpg[/img]	2014-04-27 18:02:13+00	204	t
2	16	81	[commentquote=[user]PUNCHMYDICK[/user]]Inizi ad agitare la testa come se fossi ad un rave?[/commentquote]Comincio a spaccare i carrelli in testa alle cassiere e a sputare sulle nonnine che mi passano vicino	2014-04-27 18:02:40+00	205	t
2	2	86	[commentquote=[user]admin[/user]]peppe[/commentquote]nah[hr]e poi ho detto che sono su nerdz :V	2014-04-27 18:03:38+00	206	t
16	16	81	Pff nub	2014-04-27 18:04:01+00	207	t
1	2	86	xeno	2014-04-27 18:26:26+00	212	t
1	16	81	Lots of retards here.	2014-04-27 18:36:47+00	213	t
2	16	81	[commentquote=[user]admin[/user]]Lots of retards here.[/commentquote]tards pls, tards	2014-04-27 20:03:08+00	219	t
2	1	92	EBBASTA NN FR POST GEMELI ECCHECCAZZO	2014-04-27 20:04:18+00	220	t
16	16	84	pic || gtfo pls	2014-04-27 20:20:02+00	221	t
16	14	90	&lt;3	2014-04-27 20:20:29+00	222	t
16	1	87	io vedo gente	2014-04-27 20:20:41+00	223	t
1	1	87	&gt;TU\n&gt;VEDERE GENTE\n\nAHAHAHAHHAHAHAHAHAHAHAHAHA	2014-04-27 20:25:18+00	224	t
1	16	81	MR SWAG SPEAKING	2014-04-27 20:25:50+00	225	t
16	1	87	La guardo da lontano, con un binocolo.	2014-04-27 20:27:48+00	226	t
16	1	99	AUTISM	2014-04-27 20:28:13+00	227	t
2	16	84	[img]http://www.altarimini.it/immagini/news_image/peppa-pig.jpg[/img]\n[img]http://www.blogsicilia.it/wp-content/uploads/2013/11/peppa-pig-400x215.jpg[/img][hr]PS era un&#039;orgia	2014-04-27 20:35:22+00	228	t
2	1	99	ASSWAG	2014-04-27 20:36:11+00	229	t
16	16	84	[img]http://titastitas.files.wordpress.com/2013/06/peppa-pig-cazzo-big-cumshot.jpg[/img]	2014-04-27 20:36:20+00	230	t
2	16	101	smoke weed every day	2014-04-27 20:36:35+00	231	t
2	16	84	EHI KI TI PASSA CERTE IMG EH? SONO PVT	2014-04-27 20:37:35+00	232	t
16	16	84	HO LE MIE FONTI	2014-04-27 20:38:16+00	233	t
2	16	84	[commentquote=[user]PUNCHMYDICK[/user]]HO LE MIE FONTI[/commentquote]NON SARA&#039; MICA QUEL GRAN PORCO DI MIO MARITO/FIGLIO? :0	2014-04-27 20:39:53+00	234	t
20	4	26	TU MAMMA SE FA LE PIPPE	2014-04-27 20:49:52+00	235	t
2	20	102	Trova uno specchio e... SEI ARRIVATO!	2014-04-27 21:11:30+00	236	t
20	20	102	A BELLO DE CASA TE PISCIO MBOCCA PORCO DE DIO	2014-04-27 21:15:18+00	237	t
2	20	102	[commentquote=[user]SBURRO[/user]]A BELLO DE CASA TE PISCIO MBOCCA PORCO DE DIO[/commentquote]EHI IO SONO PEPPAPIG LA MAIALA PIU&#039; MAIALA CHE C&#039;E&#039;, VACCI PIANO CON GLI INSULTI!	2014-04-27 23:07:37+00	238	t
20	20	102	A BEDDA DE ZIO IO TE T&#039;AFFETTO NCINQUE SECONDI SI TE TROVO	2014-04-27 23:13:43+00	239	t
20	3	60	BEDDI, VOREI PARLA L&#039;INGLISH MA ME SA CHE NUN SE PO FA PE OGGI. NER FRATTEMPO CHE ME LO MPARE FAMOSE NA CANNETTA. DAJE MPO	2014-04-27 23:15:01+00	240	t
2	20	102	A BEDDO L&#039;ULTIMA PERSONA CHE HA PROVATO AD AFFETTAMME STA A FA CONGIME PE FIORI	2014-04-27 23:31:21+00	241	t
2	1	103	wow so COOL	2014-04-27 23:31:59+00	242	t
1	15	105	[user]gesù3[/user] wtf?	2014-10-09 07:58:30+00	243	t
\.


--
-- Name: comments_hcid_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('comments_hcid_seq', 243, true);


--
-- Data for Name: comments_no_notify; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY comments_no_notify ("from", "to", hpid, "time", counter) FROM stdin;
\.


--
-- Name: comments_no_notify_id_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('comments_no_notify_id_seq', 1, false);


--
-- Data for Name: comments_notify; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY comments_notify ("from", "to", hpid, "time", counter) FROM stdin;
15	13	54	2014-04-26 18:08:59+00	1
1	4	26	2014-04-26 15:48:01+00	2
20	4	26	2014-04-27 20:49:52+00	3
20	1	26	2014-04-27 20:49:52+00	4
20	3	60	2014-04-27 23:15:01+00	5
10	1	53	2014-04-26 18:35:27+00	6
10	12	53	2014-04-26 18:35:27+00	7
1	8	39	2014-04-26 16:51:06+00	8
2	1	64	2014-04-27 02:02:09+00	9
9	1	64	2014-04-27 08:52:11+00	10
9	8	39	2014-04-26 16:19:12+00	11
20	15	60	2014-04-27 23:15:01+00	12
20	1	60	2014-04-27 23:15:01+00	13
2	20	102	2014-04-27 23:31:21+00	14
15	3	61	2014-04-27 10:53:27+00	15
15	3	60	2014-04-27 10:53:37+00	16
2	1	103	2014-04-27 23:31:59+00	17
2	1	56	2014-04-26 16:56:55+00	18
2	20	103	2014-04-27 23:31:59+00	19
1	4	19	2014-04-27 12:50:14+00	20
2	1	63	2014-04-27 14:44:19+00	21
1	3	60	2014-04-27 17:32:03+00	22
2	1	68	2014-04-27 17:35:33+00	23
1	18	81	2014-04-27 18:36:46+00	24
17	3	59	2014-04-27 17:47:28+00	25
1	17	80	2014-04-27 18:36:54+00	26
2	1	86	2014-04-27 19:57:20+00	27
2	1	82	2014-04-27 17:54:42+00	28
2	18	81	2014-04-27 20:03:08+00	29
14	4	19	2014-04-26 17:54:24+00	30
2	1	92	2014-04-27 20:04:18+00	31
16	1	84	2014-04-27 20:20:01+00	32
16	1	82	2014-04-27 17:56:32+00	33
16	14	90	2014-04-27 20:20:28+00	34
16	1	87	2014-04-27 20:27:47+00	35
2	1	84	2014-04-27 20:34:46+00	36
\.


--
-- Name: comments_notify_id_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('comments_notify_id_seq', 36, true);


--
-- Data for Name: comments_revisions; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY comments_revisions (hcid, message, "time", rev_no, counter) FROM stdin;
\.


--
-- Name: comments_revisions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('comments_revisions_id_seq', 1, false);


--
-- Data for Name: deleted_users; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY deleted_users (counter, username, "time", motivation) FROM stdin;
\.


--
-- Data for Name: flood_limits; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY flood_limits (table_name, "time") FROM stdin;
blacklist	00:05:00
pms	00:00:01
posts	00:00:20
bookmarks	00:00:05
thumbs	00:00:02
lurkers	00:00:10
groups_posts	00:00:20
groups_bookmarks	00:00:05
groups_thumbs	00:00:02
groups_lurkers	00:00:10
comments	00:00:05
comment_thumbs	00:00:01
groups_comments	00:00:05
groups_comment_thumbs	00:00:01
followers	00:00:03
groups_followers	00:00:03
\.


--
-- Data for Name: followers; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY followers ("from", "to", to_notify, "time", counter) FROM stdin;
1	4	f	2014-04-26 15:38:53+00	1
2	13	f	2014-04-26 16:45:44+00	2
4	1	f	2014-04-26 15:39:04+00	3
6	1	f	2014-04-26 16:00:50+00	4
2	1	f	2014-04-26 16:13:16+00	5
1	14	t	2014-04-27 19:25:19+00	6
13	1	t	2014-04-26 17:08:17+00	7
1	16	f	2014-04-27 17:51:33+00	8
6	10	f	2014-04-26 16:31:01+00	9
1	2	f	2014-04-26 16:12:54+00	10
13	2	f	2014-04-26 16:44:52+00	11
16	1	t	2014-04-27 17:57:48+00	12
\.


--
-- Name: followers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('followers_id_seq', 12, true);


--
-- Data for Name: groups; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY groups (counter, description, name, private, photo, website, goal, visible, open, creation_time) FROM stdin;
2	A simple project in which I&#039;ll go to explain all the wonderful techniques available in the machine learning&#039;s field	Artificial Intelligence	f	\N	\N		t	f	2014-10-09 07:55:21+00
3	MERDZilla - where we don&#039;t solve your bugs.	NERDZilla	f	\N	\N		t	f	2014-04-26 15:34:17+00
7	QUA SE FAMO LE CANNE ZI&#039;	SCALDA E ROLLA	f	\N	\N		t	f	2014-04-27 20:49:00+00
4	Per tutti gli amanti degli Ananas	Ananas &hearts;	f	http://tarbawiyat.freehostia.com/francais/Cours3/a/ananas.jpg		Far amare gli ananas a tutti	t	t	2014-04-26 16:28:14+00
5	.	CANI	f	\N	\N		t	f	2014-04-26 16:41:05+00
6	IL GOMBLODDO	GOMBLODDI	f	\N	\N		t	f	2014-04-27 18:39:49+00
1	PROGETTO	PROGETTO	f	http://www.matematicamente.it/forum/styles/style-matheme_se/imageset/logo.2013-200x48.png	http://www.sitoweb.info	fare cose	t	t	2014-04-26 15:14:04+00
\.


--
-- Data for Name: groups_bookmarks; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY groups_bookmarks ("from", hpid, "time", counter) FROM stdin;
1	1	2014-04-26 16:14:29+00	1
6	2	2014-04-26 16:30:34+00	2
6	1	2014-04-26 16:30:49+00	3
1	3	2014-04-27 19:28:52+00	4
\.


--
-- Name: groups_bookmarks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('groups_bookmarks_id_seq', 4, true);


--
-- Data for Name: groups_comment_thumbs; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY groups_comment_thumbs (hcid, "from", vote, "time", "to", counter) FROM stdin;
\.


--
-- Name: groups_comment_thumbs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('groups_comment_thumbs_id_seq', 1, false);


--
-- Data for Name: groups_comments; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY groups_comments ("from", "to", hpid, message, "time", hcid, editable) FROM stdin;
2	1	2	WOW, &egrave; meraviglierrimo :O	2014-04-26 15:21:42+00	1	t
1	1	2	Non so usare windows. Non mangio le mele. In un&#039;altra vita ero Hacker, in questa sono Developer. Ho il vaffanculo facile: stammi alla larga. #DefollowMe	2014-04-26 15:21:57+00	2	t
1	5	7	figooooooooooooooo[hr]FIGO	2014-04-27 17:52:08+00	3	t
10	5	7	LOL	2014-04-27 18:38:33+00	4	t
1	3	3	I LOVE YOU GABE	2014-04-27 19:28:57+00	5	t
\.


--
-- Name: groups_comments_hcid_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('groups_comments_hcid_seq', 5, true);


--
-- Data for Name: groups_comments_no_notify; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY groups_comments_no_notify ("from", "to", hpid, "time", counter) FROM stdin;
\.


--
-- Name: groups_comments_no_notify_id_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('groups_comments_no_notify_id_seq', 1, false);


--
-- Data for Name: groups_comments_notify; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY groups_comments_notify ("from", "to", hpid, "time", counter) FROM stdin;
1	12	7	2014-04-27 17:52:07+00	1
10	12	7	2014-04-27 18:38:32+00	2
10	1	7	2014-04-27 18:38:32+00	3
1	4	3	2014-04-27 19:28:57+00	4
\.


--
-- Name: groups_comments_notify_id_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('groups_comments_notify_id_seq', 4, true);


--
-- Data for Name: groups_comments_revisions; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY groups_comments_revisions (hcid, message, "time", rev_no, counter) FROM stdin;
\.


--
-- Name: groups_comments_revisions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('groups_comments_revisions_id_seq', 1, false);


--
-- Name: groups_counter_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('groups_counter_seq', 7, true);


--
-- Data for Name: groups_followers; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY groups_followers ("to", "from", "time", to_notify, counter) FROM stdin;
2	1	2014-10-09 07:55:21+00	f	1
4	1	2014-10-09 07:55:21+00	f	2
\.


--
-- Name: groups_followers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('groups_followers_id_seq', 2, true);


--
-- Data for Name: groups_lurkers; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY groups_lurkers ("from", hpid, "time", "to", counter) FROM stdin;
13	4	2014-04-26 16:47:02+00	4	1
13	5	2014-04-26 16:47:01+00	4	2
13	6	2014-04-26 16:47:00+00	4	3
6	2	2014-04-26 16:30:30+00	1	4
6	1	2014-04-26 16:30:49+00	1	5
\.


--
-- Name: groups_lurkers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('groups_lurkers_id_seq', 5, true);


--
-- Data for Name: groups_members; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY groups_members ("to", "from", "time", to_notify, counter) FROM stdin;
1	15	2014-10-09 07:55:21+00	f	1
\.


--
-- Name: groups_members_id_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('groups_members_id_seq', 1, true);


--
-- Data for Name: groups_notify; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY groups_notify ("from", "to", "time", hpid, counter) FROM stdin;
4	6	2014-04-27 19:28:43+00	4	1
\.


--
-- Name: groups_notify_id_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('groups_notify_id_seq', 1, true);


--
-- Data for Name: groups_owners; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY groups_owners ("to", "from", "time", to_notify, counter) FROM stdin;
2	3	2014-10-09 07:55:21+00	f	1
3	4	2014-04-26 15:34:17+00	f	2
7	20	2014-04-27 20:49:00+00	f	3
4	6	2014-04-26 16:28:14+00	f	4
5	12	2014-04-26 16:41:05+00	f	5
6	1	2014-04-27 18:39:49+00	f	6
1	1	2014-04-26 15:14:04+00	f	7
\.


--
-- Name: groups_owners_id_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('groups_owners_id_seq', 7, true);


--
-- Data for Name: groups_posts; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY groups_posts (hpid, "from", "to", pid, message, "time", news, lang, closed) FROM stdin;
3	4	3	1	Half Life 3 has been confirmed.	2014-04-26 15:34:17+00	t	en	f
13	20	7	1	IO CE METTO ER FUMO E VOI ROLLATE LE CANNE.	2014-04-27 20:49:00+00	f	en	f
4	6	4	1	[img]http://pharm1.pharmazie.uni-greifswald.de/systematik/7_bilder/yamasaki/yamas686.jpg[/img]\nQui possiamo vedere un esemplare tipico di Ananas	2014-04-26 16:28:14+00	f	it	f
5	6	4	2	[img]http://www.bzi.ro/public/upload/photos/43/ananas.jpg[/img]\nEd ecco alcuni ananas di fila	2014-04-26 16:28:54+00	f	it	f
6	6	4	3	[img]http://static.pourfemme.it/pfwww/fotogallery/625X0/67021/ananas-a-fette.jpg[/img]\nOra il punto forte, ananas a fette	2014-04-26 16:29:38+00	f	it	f
7	12	5	1	CUI CI SONO CANI\n[yt]\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n[/yt]	2014-04-26 16:41:05+00	t	en	f
11	1	4	4	I LOVE ANANAS. THANK YOU!	2014-04-27 19:28:43+00	f	it	f
10	1	6	2	i post sui progetti sono be3lli	2014-04-27 19:28:23+00	f	it	f
9	1	6	1	GOMBLODDO [news]	2014-04-27 18:39:49+00	t	it	f
12	1	1	4	anzi, sono bellissimi :D:D:D:D:D:D:	2014-04-27 19:29:03+00	t	it	f
8	1	1	3	NUOVO POST NEL PROGETTO\n	2014-04-27 17:51:18+00	t	it	f
2	1	1	2	HO GI&Agrave; DETTO PROGETTO?	2014-04-26 15:15:49+00	t	it	f
1	1	1	1	PROGETTO DOVE SCRIVO PROGETTO	2014-04-26 15:14:04+00	t	it	f
\.


--
-- Name: groups_posts_hpid_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('groups_posts_hpid_seq', 13, true);


--
-- Data for Name: groups_posts_no_notify; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY groups_posts_no_notify ("user", hpid, "time", counter) FROM stdin;
\.


--
-- Name: groups_posts_no_notify_id_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('groups_posts_no_notify_id_seq', 1, false);


--
-- Data for Name: groups_posts_revisions; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY groups_posts_revisions (hpid, message, "time", rev_no, counter) FROM stdin;
\.


--
-- Name: groups_posts_revisions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('groups_posts_revisions_id_seq', 1, false);


--
-- Data for Name: groups_thumbs; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY groups_thumbs (hpid, "from", vote, "time", "to", counter) FROM stdin;
3	1	1	2014-10-09 07:55:21+00	4	1
4	1	1	2014-10-09 07:55:21+00	6	2
6	1	-1	2014-10-09 07:55:21+00	6	3
\.


--
-- Name: groups_thumbs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('groups_thumbs_id_seq', 3, true);


--
-- Data for Name: guests; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY guests (remote_addr, http_user_agent, last) FROM stdin;
\.


--
-- Data for Name: lurkers; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY lurkers ("from", hpid, "time", "to", counter) FROM stdin;
6	2	2014-04-26 17:00:57+00	1	1
3	15	2014-04-26 15:32:55+00	4	2
3	16	2014-04-26 15:32:54+00	4	3
1	20	2014-04-26 15:38:27+00	4	4
6	22	2014-04-26 17:00:02+00	1	5
6	39	2014-04-26 16:17:22+00	8	6
6	27	2014-04-26 16:02:38+00	5	7
6	33	2014-04-26 16:08:32+00	2	8
6	35	2014-04-26 16:08:30+00	1	9
6	37	2014-04-26 16:18:06+00	8	10
6	44	2014-04-26 16:27:29+00	11	11
12	48	2014-04-26 16:36:47+00	9	12
1	53	2014-04-26 16:53:38+00	12	13
3	58	2014-04-26 18:16:36+00	14	14
\.


--
-- Name: lurkers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('lurkers_id_seq', 14, true);


--
-- Data for Name: mentions; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY mentions (id, u_hpid, g_hpid, "from", "to", "time", to_notify) FROM stdin;
1	105	\N	15	1	2014-10-09 07:57:39+00	t
2	105	\N	1	15	2014-10-09 07:58:30+00	t
\.


--
-- Name: mentions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('mentions_id_seq', 2, true);


--
-- Data for Name: pms; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY pms ("from", "to", "time", message, to_read, pmid) FROM stdin;
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

COPY posts (hpid, "from", "to", pid, message, "time", lang, news, closed) FROM stdin;
2	1	1	1	Postare &egrave; molto bello.	2014-04-26 15:03:27+00	it	f	f
3	1	1	2	&Egrave; davvero uno spasso fare post :&gt;	2014-04-26 15:03:47+00	it	f	f
4	1	1	3	Quando un admin si sente solo non pu&ograve; fare altro che spammare e postare.	2014-04-26 15:04:15+00	it	f	f
5	1	1	4	[img]https://fbcdn-sphotos-f-a.akamaihd.net/hphotos-ak-frc1/t1.0-9/q71/s720x720/10295706_754761757878221_576570612184366073_n.jpg[/img] SALVO AIUTAMI TU	2014-04-26 15:04:47+00	it	f	f
6	1	1	5	Sono il primo ed ultimo utente :&lt;	2014-04-26 15:06:01+00	it	f	f
8	2	2	1	Tutto in portoghese, non si capisce una minchiao	2014-04-26 15:10:25+00	pt	f	f
9	1	1	6	VENITE A VEDERE IL MIO NUOVO [PROJECT]PROGETTO[/PROJECT], BELILSSIMO [PROJECT]PROGETTO[/PROJECT]. STUPENDO [PROJECT]PROGETTO[/PROJECT]	2014-04-26 15:14:29+00	it	f	f
10	1	1	7	MEGLIO DI SALVO C&#039;&Egrave; SOLO PATRICK	2014-04-26 15:22:36+00	it	f	f
12	4	4	1	[url=http://gaben.tv]My personal website[/url].	2014-04-26 15:26:37+00	en	f	f
11	1	3	1	Hi, welcome on NERDZ! How did you find this website?	2014-04-26 15:26:06+00	en	f	f
14	2	2	2	ALL HAIL THE PIG	2014-04-26 15:28:25+00	pt	f	f
13	3	3	2	Hi there.\nI&#039;m mitchell and I&#039;m a computer scientist from Amsterdam.\n\nI&#039;ll try to make a post here in order to understand if this box has been correctly set up.	2014-04-26 15:26:43+00	en	f	f
15	4	4	2	I think we should rename this site to &quot;MERDZ&quot;.	2014-04-26 15:28:30+00	en	f	f
16	1	4	3	[img]http://i.imgur.com/4VkOPTx.gif[/img]\nYOU.\nARE.\nTHE.\nMAN.	2014-04-26 15:31:43+00	en	f	f
17	4	4	4	[img]http://upload.wikimedia.org/wikipedia/commons/6/66/Gabe_Newell_GDC_2010.jpg[/img]	2014-04-26 15:33:04+00	en	f	f
18	1	1	8	&gt;@beppe_grillo minaccia di uscire dall&#039;euro usando la bufala dei 50 miliardi l&#039;anno del fiscal compact.\n\nVIA VIA BEPPE	2014-04-26 15:33:29+00	it	f	f
19	1	1	9	Desktop thread? Desktop thread.\n[img]http://i.imgur.com/muyPP.png[/img]	2014-04-26 15:36:11+00	it	f	f
20	4	4	5	[url=http://freddy.niggazwithattitu.de/]Check out this website![/url]	2014-04-26 15:36:20+00	en	f	f
21	1	1	10	Non l&#039;ho mai detto. Ma mi piacciono le formiche.	2014-04-26 15:40:07+00	it	f	f
22	1	1	11	I miei posts sono pieni d&#039;amore ed odio. Dov&#039;&egrave; madalby :&lt;  :&lt; :&lt;	2014-04-26 15:40:27+00	it	f	f
23	4	4	6	You can&#039;t withstand my swagness.\n[img]https://fbcdn-sphotos-c-a.akamaihd.net/hphotos-ak-ash3/550353_521879527824004_1784603382_n.jpg[/img]	2014-04-26 15:41:58+00	en	f	f
25	5	5	1	[yt]https://www.youtube.com/watch?v=GmbEpMVqNt0[/yt]	2014-04-26 15:46:50+00	en	f	f
39	2	8	2	SPORCO IMPOSTORE! SONO IO L&#039;UNICA MAIALA QUI DENTRO, CAPITO? VAI VIA [small]xeno[/small]	2014-04-26 16:14:24+00	it	f	f
26	4	4	7	I have to go now, forever.\n[i]See you in the next era.[/i]	2014-04-26 15:47:25+00	en	f	f
38	1	2	4	que bom Peppa n&oacute;s somos amigos agora!	2014-04-26 16:13:57+00	pt	f	f
27	1	5	2	Hi and welcome on NERDZ MEGANerchia! How did you find this website?	2014-04-26 15:48:28+00	en	f	f
28	5	5	3	Sto sito &egrave; nbicchiere de piscio	2014-04-26 15:51:35+00	en	f	f
29	1	6	1	REAL OR FAKE?	2014-04-26 15:51:46+00	it	f	f
31	6	6	2	Btw c&#039;&egrave; qualche problema col cambio di nick o sbaglio? asd	2014-04-26 15:54:13+00	it	f	f
33	2	2	3	Una domanda: come si cambia avatar? lel	2014-04-26 16:02:21+00	pt	f	f
34	1	6	3	Tu mangi le mele?	2014-04-26 16:02:55+00	it	f	f
24	1	1	12	@ * CHECKOUT MY PROFILE PAGE. UPDATED INTERESTS AND QUOTES.\n\n[ITA] Guardate il mio profilo, ho aggiornato gli interessi e le citazioni :D\n\n[DE] Banane :&gt;\n[hr] Hrvatz !! LOL!!!\n[FR] Je suis un fille fillo\n\n[PT] U SEXY MAMA BABY	2014-04-26 15:46:23+00	it	f	f
35	1	1	13	[URL]http://translate.google.it[/URL] un link utile!	2014-04-26 16:07:44+00	it	f	f
36	1	4	8	I miss you :&lt;	2014-04-26 16:10:38+00	en	f	f
37	1	8	1	NON SEI SIMPATICO TU\n\n[small]forse s&igrave;[/SMALL]	2014-04-26 16:12:47+00	it	f	f
40	9	9	1	PLS, YOUR SISTEM IS OWNED	2014-04-26 16:18:46+00	it	f	f
41	2	2	5	Il re joffrey &egrave; un figo della madonna, ho un poster gigante sul soffitto e mi masturbo ogni notte pensando a lui. &lt;3	2014-04-26 16:18:49+00	pt	f	f
42	10	10	1	\\o/	2014-04-26 16:19:29+00	en	f	f
43	11	11	1	[YT]http://www.youtube.com/watch?v=Ju8Hr50Ckwk[/YT]\nCHE BRAVA ALICIA	2014-04-26 16:24:16+00	it	f	f
44	2	11	2	Ciao gufo, io sono una maiala, piacere :3	2014-04-26 16:25:14+00	it	f	f
45	2	9	2	VAI VIA PTKDEV	2014-04-26 16:31:39+00	it	f	f
48	9	9	3	SICURAMENTE QUESTO SITO SALVA LE PASSOWRD IN CHIARO	2014-04-26 16:35:25+00	it	f	f
49	12	12	1	GOMBLOTTTOF	2014-04-26 16:36:09+00	en	f	f
50	9	13	1	AAHAHHAHAHAHAHAHAHAHAH LA TUA PRIVACY &Egrave; A RISCHIO	2014-04-26 16:37:32+00	it	f	f
52	12	12	2	CIOE SECND ME PEPPE CRILLO VUOLE SL CS MEGLI PE NOI NN CM CUEI LA CSTA	2014-04-26 16:38:05+00	en	f	f
51	9	11	3	AAHAHHAHAHAHAHAHAHAHAH HO IL DUMP DEL DATABASE. JAVASCRIPQL INJECTION	2014-04-26 16:37:59+00	it	f	f
53	12	12	3	We are planning our move from MySQL on EC2 to MySQL RDS.\none of the things we do quite frequently is mysqldump to get quick snapshots of a single DB.\nI read in the documentation that RDS allows for up to 30 dbs on a single instance but I have not yet seen a way in the console to dump single DB.\nAny advice?	2014-04-26 16:43:35+00	en	f	f
54	13	13	2	[wiki=it]Risotto alla milanese[/wiki]	2014-04-26 16:44:00+00	it	f	f
56	2	2	7	Siete delle merde, dovete mettervi la board in altre lingue != (Italiano|English)	2014-04-26 16:45:33+00	pt	f	f
55	13	2	6	Buona sera, signora porca	2014-04-26 16:45:06+00	pt	f	f
47	2	1	14	[yt]https://www.youtube.com/watch?v=CLEtGRUrtJo&amp;feature=kp[/yt]	2014-04-26 16:33:13+00	it	f	f
32	7	7	1	HAI I&#039;M THE USER WHO LOVES TO LOG NEWS	2014-04-26 15:58:50+00	it	t	f
46	7	7	2	Doch %%12now is34%% [user]Ananas[/user].	2014-04-26 16:32:53+00	it	t	f
105	15	15	3	[user]admin[/user] come here, pls	2014-10-09 07:57:39+00	en	f	f
107	1	1	29	#ILoveHashTags	2014-10-09 07:58:09+00	it	f	f
57	2	13	3	[quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u][quote=105|u]	2014-04-26 17:16:15+00	it	f	f
58	9	14	1	OH YOU NOOB	2014-04-26 17:57:45+00	it	f	f
59	15	14	2	YOU FUCKING FAKE	2014-04-26 18:06:29+00	it	f	f
60	15	3	3	Hello, can I  insult your god?	2014-04-26 18:07:13+00	en	f	f
91	1	1	22	[USER]NOT FOUND :&lt;[/user]	2014-04-27 19:26:33+00	it	f	f
92	1	1	23	[yt]https://www.youtube.com/watch?v=WULsZJxPfws[/yt]\nN E V E R - F O R G E T	2014-04-27 19:34:55+00	it	f	f
93	2	2	12	G	2014-04-27 20:14:24+00	pt	f	f
62	3	3	4	[code=Fuck]\nA fuck, in the fuck, fuck a fuck in the fucking fuck\n[/code]\n\n[code=gombolo]\n[/code]	2014-04-26 18:16:51+00	en	f	f
63	2	2	8	Siete tutti dei buzzurri	2014-04-26 20:51:44+00	pt	f	f
64	1	1	15	LOL ORA TARDA FTW	2014-04-27 00:53:04+00	it	f	f
65	9	9	4	No cio&egrave;, davvero yahoo!? [img]http://i.imgur.com/Gg8T4ph.png[/img]	2014-04-27 09:00:35+00	it	f	f
66	1	1	16	[img]https://pbs.twimg.com/media/BmK27EHIMAIKO0q.jpg[/img]	2014-04-27 09:02:50+00	it	f	f
61	14	15	1	FAKE	2014-04-26 18:15:19+00	it	f	f
67	15	15	2	[img]http://i.imgur.com/vrF4D09.png[/img]	2014-04-27 13:38:35+00	it	f	f
68	1	2	9	Peppa, eu realmente aprecio a sua usar ativamente esta vers&atilde;o do nerdz\n\nxoxo	2014-04-27 17:04:57+00	pt	f	f
69	1	1	17	[img]http://i.imgur.com/vrF4D09.png[/img] :O	2014-04-27 17:30:08+00	it	f	f
70	1	1	18	Golang api leaked\n[code=go]package nerdz\nimport (\n        &quot;github.com/jinzhu/gorm&quot;\n        &quot;net/url&quot;\n)\n// Informations common to all the implementation of Board\ntype Info struct {\n        Id        int64\n        Owner     *User\n        Followers []*User\n        Name      string\n        Website   *url.URL\n        Image     *url.URL\n}\n// PostlistOptions is used to specify the options of a list of posts.\n// The 4 fields are documented and can be combined.\n//\n// If Following = Followers = true -&gt; show posts FROM user that I follow that follow me back (friends)\n// If Older != 0 &amp;&amp; Newer != 0 -&gt; find posts BETWEEN this 2 posts\n//\n// For example:\n// - user.GetUserHome(&amp;PostlistOptions{Followed: true, Language: &quot;en&quot;})\n// returns at most the last 20 posts from the english speaking users that I follow.\n// - user.GetUserHome(&amp;PostlistOptions{Followed: true, Following: true, Language: &quot;it&quot;, Older: 90, Newer: 50, N: 10})\n// returns at most 10 posts, from user&#039;s friends, speaking italian, between the posts with hpid 90 and 50\ntype PostlistOptions struct {\n        Following bool   // true -&gt; show posts only FROM following\n        Followers bool   // true -&gt; show posts only FROM followers\n        Language  string // if Language is a valid 2 characters identifier, show posts from users (users selected enabling/disabling following &amp; folowers) speaking that Language\n        N         int    // number of post to return (min 1, max 20)\n        Older     int64  // if specified, tells to the function using this struct to return N posts OLDER (created before) than the post with the specified &quot;Older&quot; ID\n        Newer     int64  // if specified, tells to the function using this struct to return N posts NEWER (created after) the post with the specified &quot;Newer&quot;&quot; ID\n}\n\n// Board is the representation of a generic Board.\n// Every board has its own Informations and Postlist\ntype Board interface {\n        GetInfo() *Info\n        // The return value type of GetPostlist must be changed by type assertion.\n        GetPostlist(*PostlistOptions) interface{}\n}\n\n// postlistQueryBuilder returns the same pointer passed as first argument, with new specified options setted\n// If the user parameter is present, it&#039;s intentend to be the user browsing the website.\n// So it will be used to fetch the following list -&gt; so we can easily find the posts on a bord/project/home/ecc made by the users that &quot;user&quot; is following\nfunc postlistQueryBuilder(query *gorm.DB, options *PostlistOptions, user ...*User) *gorm.DB {\n        if options == nil {\n                return query.Limit(20)\n        }\n\n        if options.N &gt; 0 &amp;&amp; options.N &lt; 20 {\n                query = query.Limit(options.N)\n        } else {\n                query = query.Limit(20)\n        }\n\n        userOK := len(user) == 1 &amp;&amp; user[0] != nil\n\n        if !options.Followers &amp;&amp; options.Following &amp;&amp; userOK { // from following + me\n                following := user[0].getNumericFollowing()\n                if len(following) != 0 {\n                        query = query.Where(&quot;\\&quot;from\\&quot; IN (? , ?)&quot;, following, user[0].Counter)\n                }\n        } else if !options.Following &amp;&amp; options.Followers &amp;&amp; userOK { //from followers + me\n                followers := user[0].getNumericFollowers()\n                if len(followers) != 0 {\n                        query = query.Where(&quot;\\&quot;from\\&quot; IN (? , ?)&quot;, followers, user[0].Counter)\n                }\n        } else if options.Following &amp;&amp; options.Followers &amp;&amp; userOK { //from friends + me\n                follows := new(UserFollow).TableName()\n                query = query.Where(&quot;\\&quot;from\\&quot; IN ( (SELECT ?) UNION  (SELECT \\&quot;to\\&quot; FROM (SELECT \\&quot;to\\&quot; FROM &quot;+follows+&quot; WHERE \\&quot;from\\&quot; = ?) AS f INNER JOIN (SELECT \\&quot;from\\&quot; FROM &quot;+follows+&quot; WHERE \\&quot;to\\&quot; = ?) AS e on f.to = e.from) )&quot;, user[0].Counter, user[0].Counter, user[0].Counter)\n        }\n\n        if options.Language != &quot;&quot; {\n                query = query.Where(&amp;User{Lang: options.Language})\n        }\n\n        if options.Older != 0 &amp;&amp; options.Newer != 0 {\n                query = query.Where(&quot;hpid BETWEEN ? AND ?&quot;, options.Newer, options.Older)\n        } else if options.Older != 0 {\n                query = query.Where(&quot;hpid &lt; ?&quot;, options.Older)\n        } else if options.Newer != 0 {\n                query = query.Where(&quot;hpid &gt; ?&quot;, options.Newer)\n        }\n\n        return query\n}[/code]	2014-04-27 17:31:02+00	it	f	f
72	1	1	19	Tutto questo &egrave; bellissimo &lt;3&lt;34	2014-04-27 17:31:51+00	it	f	f
73	2	2	10	E&#039; meraviglioso il fatto che ci sia pi&ugrave; attivit&agrave; qui che sul nerdz non farlocco lol	2014-04-27 17:37:03+00	pt	f	f
74	16	16	1	LEL	2014-04-27 17:39:18+00	it	f	f
75	16	16	2	DIO	2014-04-27 17:41:45+00	it	f	f
76	16	16	3	BOIA	2014-04-27 17:42:27+00	it	f	f
77	16	16	4	MI GRATTO IL CULO E ANNUSO LA MANO	2014-04-27 17:42:47+00	it	f	f
78	2	16	5	Hola, sono la porca della situazione, piacere di conoscerti :v	2014-04-27 17:43:17+00	it	f	f
79	16	16	6	ღ Beppe ღ ha risposto 5 anni fa\nIl sesso anale non dovrebbe fare male. Se fa male lo state facendo in maniera sbagliata. Con abbastanza lubrificante e abbastanza pazienza, &egrave; possibilissimo godersi il sesso anale come una parte sicura e soddisfacente della vostra vita sessuale. Comunque, ad alcune persone non piacer&agrave; mai, e se il tuo/la tua amante &egrave; una di queste persone, rispetta i suoi limiti. Non forzarli. \nIl piacere dato dal sesso anale deriva da molti fattori. Fare qualcosa di &quot;schifoso&quot; attrae molte persone, specialmente per quanto riguarda il sesso. Fare qualcosa di diverso per mettere un po&#039; di pepe in una vita sessuale che &egrave; diventata noiosa pu&ograve; essere una ragione. E le sensazioni fisiche che si provano durante il sesso anale sono completamente differenti da qualsiasi altra cosa. Il retto &egrave; pieno di terminazioni nervose, alcune delle quali stimolano il cervello a premiare la persona con sensazioni gradevoli quando sono stimolate \nAllora innanzitutto x un rapporto anale perfetto, iniziate con un dito ben lubrificato. Lui deve far scivolare un dito dentro lentamente, lasciando che tu ti adatti. Deve tirarlo tutto fuori e rispingerlo dentro ancora. Deve lasciare il tempo al tuo ano di abituarsi a questo tipo di attivit&agrave;. Poi pu&ograve; far scivolare dentro anche un secondo dito. Poi bisogna scegliere una posizione. Molte donne vogliono stare sopra, per regolare quanto velocemente avviene la penetrazione. Ad altre piace stendersi sullo stomaco, o rannicchiarsi a mo&#039; di cane, o essere penetrate quando stanno stese sul fianco. Scegli qual&#039;&egrave; la migliore prima di iniziare. \nCome sempre, controllati. Rilassati e usa molto lubrificante. Le persone che amano il sesso anale dicono &quot;troppo lubrificante &egrave; quasi abbastanza&quot;. \nArriver&agrave; un momento in cui il tuo ano sar&agrave; abbastanza rilassato da permettere alla testa del suo pene di entrare facilmente dentro di te. Se sei completamente rilassata, dovrebbe risultare completamente indolore. Ora solo perch&eacute; &egrave; dentro di te, non c&#039;&egrave; ragione di iniziare a bombardarti come un matto. Lui deve lasciare che il tuo corpo si aggiusti. Digli di fare con calma. Eventualmente sarete entrambi pronti per qualcosa di pi&ugrave;. \nAnche se sei sicura che sia tu,sia il tuo partner non avete malattie, dovreste lo stesso usare un preservativo. Nel retto ci sono molti batteri che possono causare bruciature e uretriti del pene. \nSe vuoi usare il sesso anale come contraccettivo, non farlo. \nIl sesso anale non &egrave; un buon metodo contraccettivo. La perdita di sperma dall&#039;ano dopo il rapporto sessuale pu&ograve; gocciolare e causare quella che &egrave; chiamata una concezione &#039;splash&#039;. \nL&#039;ultimo consiglio, &egrave; quello di usare delle creme. Ne esistono di tantissime marche. (Pfizer, &egrave; una, ma ogni casa farmaceutica fa la sua). Basta chiedere in farmacia. Provare per credere. Importante &egrave; che non contengano farmaci, o sostanze sensibilizzanti, e non siano oleose. Potete chiedere anche creme per secchezza vaginale, attenzione per&ograve; che non contengano farmaci (ormoni o altro). Anche queste ce ne sono di tutte le marche. \nBuon divertimento.	2014-04-27 17:45:48+00	it	f	f
80	17	17	1	siano santificate le feste che iniziano con M. urliamo amen fedeli volgendo lo sguardo a un futuro pi&ugrave; mela!	2014-04-27 17:46:51+00	it	f	f
81	16	16	7	SOPRA IL LIVELLO DEL MARE\nTANTA MD PUOI TROVARE	2014-04-27 17:47:43+00	it	f	f
82	1	16	8	CIAO PUNCH	2014-04-27 17:51:05+00	it	f	f
83	16	16	9	NEL DUBBIO\nMENA	2014-04-27 17:58:05+00	it	f	f
84	16	16	10	A CHI E&#039; MAI CAPITATO DI SCOREGGIARE DURANTE UN RAPPORTO SESSUALE?	2014-04-27 18:00:55+00	it	f	f
86	2	2	11	Indovinello: chi sono su nerdz?	2014-04-27 18:01:36+00	pt	f	f
85	1	18	1	OMG	2014-04-27 18:01:27+00	it	f	f
87	1	1	20	io faccio cose	2014-04-27 18:31:53+00	it	f	f
88	1	1	21	ღ Beppe ღ ღ Beppe ღ ღ Beppe ღ	2014-04-27 18:37:16+00	it	f	f
89	10	10	2	[list start=&quot;[0-9]+&quot;]\n[*] 1\n[*] 2\n[/list]	2014-04-27 18:47:30+00	en	f	f
90	14	14	3	Quando ti rendi conto di avere pi&ugrave; notifiche qui che su nerdz capisci che fai schifo	2014-04-27 19:15:26+00	it	f	f
94	2	2	13	A	2014-04-27 20:14:45+00	pt	f	f
95	2	2	14	W	2014-04-27 20:15:05+00	pt	f	f
96	2	2	15	S	2014-04-27 20:15:24+00	pt	f	f
97	1	1	24	S	2014-04-27 20:21:24+00	it	f	f
98	1	1	25	A	2014-04-27 20:21:44+00	it	f	f
99	1	1	26	[img]http://i.imgur.com/nFyEYU0.png[/img]	2014-04-27 20:23:27+00	it	f	f
100	1	19	1	Ciao, bel nick :D:D:D:D::D	2014-04-27 20:24:21+00	it	f	f
101	16	16	11	[img]http://cdn.buzznet.com/assets/users16/geryawn/default/kitty-mindless-self-indulgence-stoned--large-msg-127354749391.jpg[/img]	2014-04-27 20:29:32+00	it	f	f
102	20	20	1	A ZII, NDO STA ER BAGNO?	2014-04-27 20:51:44+00	en	f	f
103	20	1	27	A NOBODY, TOLTO CHE ME STO A MPARA L&#039;INGLESE, ME DEVI ATTIVA L&#039;HTML CHE CE DEVO METTE LE SCRITTE FIGHE. VE QUA\n[code=html]&lt;marquee width=&quot;100%&quot; behavior=&quot;scroll&quot; scrollamount=&quot;5&quot; direction=&quot;left&quot;&gt;&lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/1/t.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/1/e.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/-.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/1/p.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/1/i.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/1/a.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/1/c.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/1/e.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/-.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/1/e.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/1/r.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/-.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/1/c.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/1/a.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/1/z.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/1/z.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;a href=&quot;http://www.scritte-glitterate.it&quot;&gt;&lt;img src=&quot;http://www.scritte-glitterate.it/glittermaker//gimg/1/o.gif&quot; border=&quot;0&quot;&gt;&lt;/a&gt; &lt;/marquee&gt;[/code]	2014-04-27 23:18:09+00	it	f	f
104	1	1	28	fff	2014-05-16 16:37:38+00	it	f	f
106	15	15	4	#RealHashtag #forRealMan	2014-10-09 07:58:00+00	it	f	f
\.


--
-- Data for Name: posts_classification; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY posts_classification (id, u_hpid, g_hpid, tag) FROM stdin;
1	70	\N	#go
2	62	\N	#Fuck
3	103	\N	#html
4	62	\N	#gombolo
5	68	\N	#code
6	33	\N	#q19
7	\N	2	#DefollowMe
8	106	\N	#RealHashtag
9	106	\N	#forRealMan
10	107	\N	#ILoveHashTags
\.


--
-- Name: posts_classification_id_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('posts_classification_id_seq', 10, true);


--
-- Name: posts_hpid_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('posts_hpid_seq', 108, true);


--
-- Data for Name: posts_no_notify; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY posts_no_notify ("user", hpid, "time", counter) FROM stdin;
3	13	2014-04-26 15:34:04+00	1
2	12	2014-04-26 15:46:11+00	2
1	38	2014-04-26 16:15:12+00	3
\.


--
-- Name: posts_no_notify_id_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('posts_no_notify_id_seq', 3, true);


--
-- Data for Name: posts_notify; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY posts_notify ("from", "to", hpid, "time", counter) FROM stdin;
1	4	36	2014-04-26 16:10:38+00	1
1	19	100	2014-04-27 20:24:21+00	2
20	1	103	2014-04-27 23:18:09+00	3
\.


--
-- Name: posts_notify_id_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('posts_notify_id_seq', 3, true);


--
-- Data for Name: posts_revisions; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY posts_revisions (hpid, message, "time", rev_no, counter) FROM stdin;
\.


--
-- Name: posts_revisions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('posts_revisions_id_seq', 1, false);


--
-- Data for Name: profiles; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY profiles (counter, website, quotes, biography, interests, github, skype, jabber, yahoo, userscript, template, mobile_template, dateformat, facebook, twitter, steam, push, pushregtime, closed, template_variables) FROM stdin;
14										0	1	d/m/Y, H:i				f	2014-04-26 17:52:37+00	f	{}
15										0	1	d/m/Y, H:i				f	2014-04-26 18:04:42+00	f	{}
16										0	1	d/m/Y, H:i				f	2014-04-27 17:38:56+00	f	{}
4										0	1	d/m/Y, H:i				f	2014-04-26 15:26:13+00	f	{}
5										0	1	d/m/Y, H:i				f	2014-04-26 15:45:31+00	f	{}
12										0	1	d/m/Y, H:i				f	2014-04-26 16:35:34+00	f	{}
13										0	1	d/m/Y, H:i				f	2014-04-26 16:35:57+00	f	{}
1	http://www.sitoweb.info	Non so usare windows. Non mangio le mele. In un&#039;altra vita ero Hacker, in questa sono Developer. Ho il vaffanculo facile: stammi alla larga. #DefollowMe	Non so usare windows. Non mangio le mele. In un&#039;altra vita ero Hacker, in questa sono Developer. Ho il vaffanculo facile: stammi alla larga. #DefollowMe	PATRIK	http://github.com/nerdzeu	spettacolo	email@bellissimadavve.ro			0	1	d/m/Y, H:i	https://www.facebook.com/profile.php?id=1111121111111	https://twitter.com/bellissimo_profilo	facciocose belle	f	2014-04-26 15:03:16+00	f	{}
10										0	1	d/m/Y, H:i				f	2014-04-26 16:18:46+00	f	{}
8										0	1	d/m/Y, H:i				f	2014-04-26 16:10:45+00	f	{}
3										0	1	d/m/Y, H:i				f	2014-04-26 15:25:21+00	f	{}
19										0	1	d/m/Y, H:i				f	2014-04-27 18:23:14+00	f	{}
17										0	1	d/m/Y, H:i				f	2014-04-27 17:45:39+00	f	{}
11										0	1	d/m/Y, H:i				f	2014-04-26 16:23:48+00	f	{}
2										0	1	d/m/Y, H:i				f	2014-04-26 15:09:06+00	f	{}
18										0	1	d/m/Y, H:i				f	2014-04-27 17:49:57+00	f	{}
9										0	1	d/m/Y, H:i				f	2014-04-26 16:18:18+00	f	{}
20										0	1	d/m/Y, H:i				f	2014-04-27 20:47:11+00	f	{}
22										0	1	d/m/Y, H:i				f	2014-05-16 16:39:58+00	f	{}
6										3	1	d/m/Y, H:i				f	2014-04-26 15:51:20+00	t	{}
7				log log						0	1	d/m/Y, H:i				f	2014-04-26 15:57:46+00	t	{}
\.


--
-- Data for Name: reset_requests; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY reset_requests (counter, remote_addr, "time", token, "to") FROM stdin;
\.


--
-- Name: reset_requests_counter_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('reset_requests_counter_seq', 1, false);


--
-- Data for Name: special_groups; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY special_groups (role, counter) FROM stdin;
ISSUE	3
GLOBAL_NEWS	1
\.


--
-- Data for Name: special_users; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY special_users (role, counter) FROM stdin;
DELETED	22
GLOBAL_NEWS	7
\.


--
-- Data for Name: thumbs; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY thumbs (hpid, "from", vote, "time", "to", counter) FROM stdin;
2	2	-1	2014-10-09 07:55:21+00	1	1
2	6	-1	2014-10-09 07:55:21+00	1	2
3	6	-1	2014-10-09 07:55:21+00	1	3
3	2	-1	2014-10-09 07:55:21+00	1	4
4	2	-1	2014-10-09 07:55:21+00	1	5
4	6	-1	2014-10-09 07:55:21+00	1	6
5	2	-1	2014-10-09 07:55:21+00	1	7
5	6	-1	2014-10-09 07:55:21+00	1	8
6	2	-1	2014-10-09 07:55:21+00	1	9
6	6	-1	2014-10-09 07:55:21+00	1	10
8	2	1	2014-10-09 07:55:21+00	2	11
8	1	-1	2014-10-09 07:55:21+00	2	12
9	2	-1	2014-10-09 07:55:21+00	1	13
9	6	-1	2014-10-09 07:55:21+00	1	14
10	2	-1	2014-10-09 07:55:21+00	1	15
10	6	-1	2014-10-09 07:55:21+00	1	16
12	20	-1	2014-10-09 07:55:21+00	4	17
11	2	-1	2014-10-09 07:55:21+00	3	18
14	2	1	2014-10-09 07:55:21+00	2	19
13	20	-1	2014-10-09 07:55:21+00	3	20
13	2	-1	2014-10-09 07:55:21+00	3	21
13	3	-1	2014-10-09 07:55:21+00	3	22
15	20	-1	2014-10-09 07:55:21+00	4	23
18	1	1	2014-10-09 07:55:21+00	1	24
18	2	-1	2014-10-09 07:55:21+00	1	25
18	6	-1	2014-10-09 07:55:21+00	1	26
19	2	-1	2014-10-09 07:55:21+00	1	27
19	6	-1	2014-10-09 07:55:21+00	1	28
21	2	-1	2014-10-09 07:55:21+00	1	29
21	6	-1	2014-10-09 07:55:21+00	1	30
22	2	-1	2014-10-09 07:55:21+00	1	31
22	6	-1	2014-10-09 07:55:21+00	1	32
25	2	-1	2014-10-09 07:55:21+00	5	33
39	2	1	2014-10-09 07:55:21+00	8	34
38	2	-1	2014-10-09 07:55:21+00	2	35
27	2	-1	2014-10-09 07:55:21+00	5	36
28	2	-1	2014-10-09 07:55:21+00	5	37
29	2	-1	2014-10-09 07:55:21+00	6	38
31	2	-1	2014-10-09 07:55:21+00	6	39
33	2	1	2014-10-09 07:55:21+00	2	40
34	2	-1	2014-10-09 07:55:21+00	6	41
34	1	1	2014-10-09 07:55:21+00	6	42
24	2	-1	2014-10-09 07:55:21+00	1	43
24	6	-1	2014-10-09 07:55:21+00	1	44
35	2	-1	2014-10-09 07:55:21+00	1	45
35	1	1	2014-10-09 07:55:21+00	1	46
35	6	1	2014-10-09 07:55:21+00	1	47
37	2	-1	2014-10-09 07:55:21+00	8	48
40	2	-1	2014-10-09 07:55:21+00	9	49
41	2	1	2014-10-09 07:55:21+00	2	50
42	2	-1	2014-10-09 07:55:21+00	10	51
43	2	-1	2014-10-09 07:55:21+00	11	52
44	2	1	2014-10-09 07:55:21+00	11	53
45	2	1	2014-10-09 07:55:21+00	9	54
48	2	-1	2014-10-09 07:55:21+00	9	55
49	2	-1	2014-10-09 07:55:21+00	12	56
49	12	1	2014-10-09 07:55:21+00	12	57
49	9	1	2014-10-09 07:55:21+00	12	58
50	2	-1	2014-10-09 07:55:21+00	13	59
50	13	-1	2014-10-09 07:55:21+00	13	60
50	6	-1	2014-10-09 07:55:21+00	13	61
52	2	-1	2014-10-09 07:55:21+00	12	62
51	2	-1	2014-10-09 07:55:21+00	11	63
51	13	-1	2014-10-09 07:55:21+00	11	64
51	6	-1	2014-10-09 07:55:21+00	11	65
51	12	1	2014-10-09 07:55:21+00	11	66
53	10	-1	2014-10-09 07:55:21+00	12	67
53	2	-1	2014-10-09 07:55:21+00	12	68
53	1	1	2014-10-09 07:55:21+00	12	69
54	2	-1	2014-10-09 07:55:21+00	13	70
54	13	1	2014-10-09 07:55:21+00	13	71
54	6	1	2014-10-09 07:55:21+00	13	72
56	2	1	2014-10-09 07:55:21+00	2	73
56	6	-1	2014-10-09 07:55:21+00	2	74
55	6	1	2014-10-09 07:55:21+00	2	75
55	2	-1	2014-10-09 07:55:21+00	2	76
47	2	1	2014-10-09 07:55:21+00	1	77
47	6	-1	2014-10-09 07:55:21+00	1	78
57	2	1	2014-10-09 07:55:21+00	13	79
58	2	-1	2014-10-09 07:55:21+00	14	80
59	2	-1	2014-10-09 07:55:21+00	14	81
60	2	-1	2014-10-09 07:55:21+00	3	82
93	2	1	2014-10-09 07:55:21+00	2	83
62	2	-1	2014-10-09 07:55:21+00	3	84
63	2	1	2014-10-09 07:55:21+00	2	85
66	1	1	2014-10-09 07:55:21+00	1	86
61	2	-1	2014-10-09 07:55:21+00	15	87
94	2	1	2014-10-09 07:55:21+00	2	88
95	2	1	2014-10-09 07:55:21+00	2	89
96	2	1	2014-10-09 07:55:21+00	2	90
97	1	1	2014-10-09 07:55:21+00	1	91
98	1	1	2014-10-09 07:55:21+00	1	92
\.


--
-- Name: thumbs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('thumbs_id_seq', 92, true);


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY users (counter, last, notify_story, private, lang, username, password, name, surname, email, gender, birth_date, board_lang, timezone, viewonline, remote_addr, http_user_agent, registration_time) FROM stdin;
22	2014-05-16 16:40:00+00	\N	f	it	fffadfsa	ff9b4f2beb6e1bdea113481fbc459ddae634f38d	fffadfsa	fffadfsa	fffadfsa@asd.it	f	2013-01-01	it	Africa/Accra	t	127.0.0.1	Mozilla/5.0 (X11; Linux x86_64; rv:29.0) Gecko/20100101 Firefox/29.0	2014-10-09 07:55:21+00
4	2014-04-26 15:47:19+00	\N	f	en	Gaben	a2edce3ae8a6e9a7ed627a9c1ea4bb9e54bd1bd0	Gabe	Newell	gaben@valve.net	t	1962-11-03	en	UTC	t	2.237.93.106	Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.116 Safari/537.36	2014-04-26 15:26:37+00
17	2014-04-27 17:48:42+00	\N	f	it	Mgonad	785a6c234db7fd83a02a568e88b65ef06073dc61	Manatma	Gonads	carne@yopmail.com	t	2009-03-13	it	Africa/Abidjan	t	2.237.93.106	Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.116 Safari/537.36	2014-04-27 17:46:51+00
7	2014-04-26 15:58:56+00	\N	f	it	newsnews	5318d1471836d989b0cb3dc0816fb380e14c379e	newsnews	newsnews	newsnews@newsnews.net	t	2007-05-03	it	UTC	t	2.237.93.106	Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.116 Safari/537.36	2014-04-26 15:58:50+00
5	2014-04-26 16:07:32+00	\N	f	en	MegaNerchia	74359506411a8497363b18248bee882b98fc2588	Mega	Nerchia	nerchia@mega.co.nz	t	2013-01-01	en	Africa/Abidjan	t	2.237.93.106	Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.116 Safari/537.36	2014-04-26 15:46:50+00
19	2014-04-27 19:10:15+00	\N	f	it	sbattiman	9d216b8d2e3f7203fa887cb3971d018181d80422	sbatti	man	vortice@gogolo.it	t	2005-08-03	it	Europe/Mariehamn	t	2.237.93.106	Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.116 Safari/537.36	2014-04-27 20:24:21+00
14	2014-04-27 19:16:04+00	\N	f	it	mcelloni	8fe455fa6cde53680789308ff66624bc886bfef7	marco	celloni	mcelloni@celle.cz	t	1995-05-03	it	America/Cambridge_Bay	t	2.237.93.106	Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.116 Safari/537.36	2014-04-26 17:57:45+00
20	2014-04-27 23:23:44+00	\N	f	en	SBURRO	4f2409154c911794cc36ce1d4180738891ef8ec2	NEL	CULO	shura1991@gmail.com	t	1988-01-01	en	Europe/Berlin	t	2.237.93.106	Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.116 Safari/537.36	2014-04-27 20:51:44+00
2	2014-04-27 23:45:14+00	\N	f	pt	PeppaPig	7e833b1c0406a1a5ee75f094fefb9899a52792b6	Giuseppina	Maiala	m1n61ux@gmail.com	f	1966-06-06	pt	Europe/Rome	t	2.237.93.106	Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.116 Safari/537.36	2014-04-26 15:10:25+00
3	2014-04-26 19:00:50+00	\N	f	en	mitchell	cf60ae0a7b2c5d57494755eec0e56113568aa6eb	Mitchell	Armand	alessandro.suglia@yahoo.com	t	2009-04-03	en	Europe/Amsterdam	t	2.237.93.106	Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.116 Safari/537.36	2014-04-26 15:26:06+00
9	2014-04-27 09:01:59+00	\N	f	it	&lt;script&gt;alert(1)	6168e894055b1da930c6418a1fdfa955884254e6	&lt;?php die(&quot;HACKED!!&quot;); ?&gt;	&lt;?php die(&quot;HACKED!!&quot;); ?&gt;	HACKER@HEKKER.NET	t	2008-02-03	it	Africa/Banjul	t	2.237.93.106	Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.116 Safari/537.36	2014-04-26 16:18:46+00
16	2014-04-27 21:24:44+00	\N	f	it	PUNCHMYDICK	48efc4851e15940af5d477d3c0ce99211a70a3be	PUNCH	MYDICK	mad_alby@hotmail.it	t	1986-05-07	it	Africa/Abidjan	t	2.237.93.106	Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.116 Safari/537.36	2014-04-27 17:39:18+00
18	2014-04-27 18:22:06+00	\N	f	it	kkklub	835c8ecbb6255e73ffcadb25e8b1ffd5bfaae5c4	ppp	mmm	dgh@fecciamail.it	f	2007-05-03	it	Africa/Casablanca	t	2.237.93.106	Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.116 Safari/537.36	2014-04-27 18:01:27+00
8	2014-04-26 16:17:54+00	\N	f	it	L&#039;Altissimo Porco	23de24af77f1d5c4fdacf90ae06cf0c10320709b	Altissimo	Ma un po&#039; porco	Highpig@safemail.info	t	1915-01-04	it	Africa/Brazzaville	t	2.237.93.106	Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.116 Safari/537.36	2014-04-26 16:12:47+00
11	2014-04-26 21:31:28+00	\N	f	it	owl	407ae5311c34cb8e20e0c7075553e99485135bed	owl	lamente	mattia@crazyup.org	t	1990-10-03	it	Europe/Rome	t	2.237.93.106	Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.116 Safari/537.36	2014-04-26 16:24:16+00
6	2014-04-27 17:38:26+00	\N	t	it	Ananas	04522cc00084518436ffdbf295b45588c041b0da	Alberto	Giaccafredda	Doch_Davidoch@safetymail.info	t	2009-04-01	it	Europe/Rome	t	2.237.93.106	Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.116 Safari/537.36	2014-04-26 15:51:46+00
10	2014-04-27 22:09:22+00	\N	f	en	winter	25119c0fa481581bdd7cf5e19805bd72a0415bc6	winter	harris0n	alfateam123@hotmail.it	f	1970-01-01	en	Africa/Abidjan	t	2.237.93.106	Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.116 Safari/537.36	2014-04-26 16:19:29+00
15	2014-10-09 07:58:40+00	\N	f	it	gesù3	bf35c33b163d5ee02d7d4dd11110daf5da341988	daitarn	tre	anal@banana.com	t	2013-12-25	hr	Europe/Rome	t	127.0.0.1	Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/37.0.2062.120 Safari/537.36	2014-04-26 18:15:19+00
12	2014-04-26 16:48:30+00	\N	f	en	Helium	55342b0fb9cf29e6d5a7649a2e02489344e49e32	Mel	Gibson	melgibson@mailinator.com	t	2009-01-09	en	Europe/Rome	t	2.237.93.106	Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.116 Safari/537.36	2014-04-26 16:36:09+00
13	2014-04-26 17:40:57+00	\N	f	it	Albero Azzurro	4724d4f09255265cb76317a2201fa94d4447a1d7	Albero	Azzurro	AA@eldelc.ecec	t	2013-01-01	it	Africa/Cairo	t	2.237.93.106	Mozilla/5.0 (Windows NT 6.3; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.116 Safari/537.36	2014-04-26 16:37:32+00
1	2015-04-06 18:45:46+00	\N	t	it	admin	dd94709528bb1c83d08f3088d4043f4742891f4f	admin	admin	admin@admin.net	t	2011-02-01	it	Europe/Rome	t	127.0.0.1	Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2272.118 Safari/537.36	2014-04-26 15:03:27+00
\.


--
-- Name: users_counter_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('users_counter_seq', 22, true);


--
-- Data for Name: whitelist; Type: TABLE DATA; Schema: public; Owner: test_db
--

COPY whitelist ("from", "to", "time", counter) FROM stdin;
\.


--
-- Name: whitelist_id_seq; Type: SEQUENCE SET; Schema: public; Owner: test_db
--

SELECT pg_catalog.setval('whitelist_id_seq', 1, false);


--
-- Name: ban_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY ban
    ADD CONSTRAINT ban_pkey PRIMARY KEY ("user");


--
-- Name: blacklist_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY blacklist
    ADD CONSTRAINT blacklist_pkey PRIMARY KEY (counter);


--
-- Name: blacklist_unique_from_to; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY blacklist
    ADD CONSTRAINT blacklist_unique_from_to UNIQUE ("from", "to");


--
-- Name: bookmarks_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY bookmarks
    ADD CONSTRAINT bookmarks_pkey PRIMARY KEY (counter);


--
-- Name: bookmarks_unique_from_hpid; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY bookmarks
    ADD CONSTRAINT bookmarks_unique_from_hpid UNIQUE ("from", hpid);


--
-- Name: comment_thumbs_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY comment_thumbs
    ADD CONSTRAINT comment_thumbs_pkey PRIMARY KEY (counter);


--
-- Name: comment_thumbs_unique_hcid_from; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY comment_thumbs
    ADD CONSTRAINT comment_thumbs_unique_hcid_from UNIQUE (hcid, "from");


--
-- Name: comments_no_notify_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY comments_no_notify
    ADD CONSTRAINT comments_no_notify_pkey PRIMARY KEY (counter);


--
-- Name: comments_no_notify_unique_from_to; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY comments_no_notify
    ADD CONSTRAINT comments_no_notify_unique_from_to UNIQUE ("from", "to");


--
-- Name: comments_notify_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY comments_notify
    ADD CONSTRAINT comments_notify_pkey PRIMARY KEY (counter);


--
-- Name: comments_notify_unique_from_to_hpid; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY comments_notify
    ADD CONSTRAINT comments_notify_unique_from_to_hpid UNIQUE ("from", "to", hpid);


--
-- Name: comments_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (hcid);


--
-- Name: comments_revisions_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY comments_revisions
    ADD CONSTRAINT comments_revisions_pkey PRIMARY KEY (counter);


--
-- Name: comments_revisions_unique_hcid_rev_no; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY comments_revisions
    ADD CONSTRAINT comments_revisions_unique_hcid_rev_no UNIQUE (hcid, rev_no);


--
-- Name: deleted_users_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY deleted_users
    ADD CONSTRAINT deleted_users_pkey PRIMARY KEY (counter);


--
-- Name: flood_limits_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY flood_limits
    ADD CONSTRAINT flood_limits_pkey PRIMARY KEY (table_name);


--
-- Name: followers_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY followers
    ADD CONSTRAINT followers_pkey PRIMARY KEY (counter);


--
-- Name: followers_unique_from_to; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY followers
    ADD CONSTRAINT followers_unique_from_to UNIQUE ("from", "to");


--
-- Name: groups_bookmarks_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_bookmarks
    ADD CONSTRAINT groups_bookmarks_pkey PRIMARY KEY (counter);


--
-- Name: groups_bookmarks_unique_from_hpid; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_bookmarks
    ADD CONSTRAINT groups_bookmarks_unique_from_hpid UNIQUE ("from", hpid);


--
-- Name: groups_comment_thumbs_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_comment_thumbs
    ADD CONSTRAINT groups_comment_thumbs_pkey PRIMARY KEY (counter);


--
-- Name: groups_comment_thumbs_unique_hcid_from; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_comment_thumbs
    ADD CONSTRAINT groups_comment_thumbs_unique_hcid_from UNIQUE (hcid, "from");


--
-- Name: groups_comments_no_notify_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_comments_no_notify
    ADD CONSTRAINT groups_comments_no_notify_pkey PRIMARY KEY (counter);


--
-- Name: groups_comments_no_notify_unique_from_to_hpid; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_comments_no_notify
    ADD CONSTRAINT groups_comments_no_notify_unique_from_to_hpid UNIQUE ("from", "to", hpid);


--
-- Name: groups_comments_notify_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_comments_notify
    ADD CONSTRAINT groups_comments_notify_pkey PRIMARY KEY (counter);


--
-- Name: groups_comments_notify_unique_from_to_hpid; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_comments_notify
    ADD CONSTRAINT groups_comments_notify_unique_from_to_hpid UNIQUE ("from", "to", hpid);


--
-- Name: groups_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_comments
    ADD CONSTRAINT groups_comments_pkey PRIMARY KEY (hcid);


--
-- Name: groups_comments_revisions_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_comments_revisions
    ADD CONSTRAINT groups_comments_revisions_pkey PRIMARY KEY (counter);


--
-- Name: groups_comments_revisions_unique_hcid_rev_no; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_comments_revisions
    ADD CONSTRAINT groups_comments_revisions_unique_hcid_rev_no UNIQUE (hcid, rev_no);


--
-- Name: groups_followers_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_followers
    ADD CONSTRAINT groups_followers_pkey PRIMARY KEY (counter);


--
-- Name: groups_followers_unique_from_to; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_followers
    ADD CONSTRAINT groups_followers_unique_from_to UNIQUE ("from", "to");


--
-- Name: groups_lurkers_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_lurkers
    ADD CONSTRAINT groups_lurkers_pkey PRIMARY KEY (counter);


--
-- Name: groups_lurkers_unique_from_hpid; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_lurkers
    ADD CONSTRAINT groups_lurkers_unique_from_hpid UNIQUE ("from", hpid);


--
-- Name: groups_members_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_members
    ADD CONSTRAINT groups_members_pkey PRIMARY KEY (counter);


--
-- Name: groups_members_unique_from_to; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_members
    ADD CONSTRAINT groups_members_unique_from_to UNIQUE ("from", "to");


--
-- Name: groups_notify_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_notify
    ADD CONSTRAINT groups_notify_pkey PRIMARY KEY (counter);


--
-- Name: groups_notify_unique_from_to; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_notify
    ADD CONSTRAINT groups_notify_unique_from_to UNIQUE ("from", "to");


--
-- Name: groups_owners_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_owners
    ADD CONSTRAINT groups_owners_pkey PRIMARY KEY (counter);


--
-- Name: groups_owners_unique_from_to; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_owners
    ADD CONSTRAINT groups_owners_unique_from_to UNIQUE ("from", "to");


--
-- Name: groups_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups
    ADD CONSTRAINT groups_pkey PRIMARY KEY (counter);


--
-- Name: groups_posts_no_notify_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_posts_no_notify
    ADD CONSTRAINT groups_posts_no_notify_pkey PRIMARY KEY (counter);


--
-- Name: groups_posts_no_notify_unique_user_hpid; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_posts_no_notify
    ADD CONSTRAINT groups_posts_no_notify_unique_user_hpid UNIQUE ("user", hpid);


--
-- Name: groups_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_posts
    ADD CONSTRAINT groups_posts_pkey PRIMARY KEY (hpid);


--
-- Name: groups_posts_revisions_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_posts_revisions
    ADD CONSTRAINT groups_posts_revisions_pkey PRIMARY KEY (counter);


--
-- Name: groups_posts_revisions_unique_hpid_rev_no; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_posts_revisions
    ADD CONSTRAINT groups_posts_revisions_unique_hpid_rev_no UNIQUE (hpid, rev_no);


--
-- Name: groups_thumbs_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_thumbs
    ADD CONSTRAINT groups_thumbs_pkey PRIMARY KEY (counter);


--
-- Name: groups_thumbs_unique_from_hpid; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_thumbs
    ADD CONSTRAINT groups_thumbs_unique_from_hpid UNIQUE ("from", hpid);


--
-- Name: guests_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY guests
    ADD CONSTRAINT guests_pkey PRIMARY KEY (remote_addr);


--
-- Name: lurkers_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY lurkers
    ADD CONSTRAINT lurkers_pkey PRIMARY KEY (counter);


--
-- Name: lurkers_unique_from_hpid; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY lurkers
    ADD CONSTRAINT lurkers_unique_from_hpid UNIQUE ("from", hpid);


--
-- Name: mentions_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY mentions
    ADD CONSTRAINT mentions_pkey PRIMARY KEY (id);


--
-- Name: pms_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY pms
    ADD CONSTRAINT pms_pkey PRIMARY KEY (pmid);


--
-- Name: posts_classification_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY posts_classification
    ADD CONSTRAINT posts_classification_pkey PRIMARY KEY (id);


--
-- Name: posts_no_notify_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY posts_no_notify
    ADD CONSTRAINT posts_no_notify_pkey PRIMARY KEY (counter);


--
-- Name: posts_no_notify_unique_user_hpid; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY posts_no_notify
    ADD CONSTRAINT posts_no_notify_unique_user_hpid UNIQUE ("user", hpid);


--
-- Name: posts_notify_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY posts_notify
    ADD CONSTRAINT posts_notify_pkey PRIMARY KEY (counter);


--
-- Name: posts_notify_unique_from_to_hpid; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY posts_notify
    ADD CONSTRAINT posts_notify_unique_from_to_hpid UNIQUE ("from", "to", hpid);


--
-- Name: posts_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (hpid);


--
-- Name: posts_revisions_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY posts_revisions
    ADD CONSTRAINT posts_revisions_pkey PRIMARY KEY (counter);


--
-- Name: posts_revisions_unique_hpid_rev_no; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY posts_revisions
    ADD CONSTRAINT posts_revisions_unique_hpid_rev_no UNIQUE (hpid, rev_no);


--
-- Name: profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (counter);


--
-- Name: reset_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY reset_requests
    ADD CONSTRAINT reset_requests_pkey PRIMARY KEY (counter);


--
-- Name: special_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY special_groups
    ADD CONSTRAINT special_groups_pkey PRIMARY KEY (role);


--
-- Name: special_users_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY special_users
    ADD CONSTRAINT special_users_pkey PRIMARY KEY (role);


--
-- Name: thumbs_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY thumbs
    ADD CONSTRAINT thumbs_pkey PRIMARY KEY (counter);


--
-- Name: thumbs_unique_from_hpid; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY thumbs
    ADD CONSTRAINT thumbs_unique_from_hpid UNIQUE ("from", hpid);


--
-- Name: uniquegroupspostpidhpid; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY groups_posts
    ADD CONSTRAINT uniquegroupspostpidhpid UNIQUE (hpid, pid);


--
-- Name: uniquemail; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT uniquemail UNIQUE (email);


--
-- Name: uniquepostpidhpid; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY posts
    ADD CONSTRAINT uniquepostpidhpid UNIQUE (hpid, pid);


--
-- Name: uniqueusername; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT uniqueusername UNIQUE (username);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (counter);


--
-- Name: whitelist_pkey; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY whitelist
    ADD CONSTRAINT whitelist_pkey PRIMARY KEY (counter);


--
-- Name: whitelist_unique_from_to; Type: CONSTRAINT; Schema: public; Owner: test_db; Tablespace: 
--

ALTER TABLE ONLY whitelist
    ADD CONSTRAINT whitelist_unique_from_to UNIQUE ("from", "to");


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

CREATE INDEX "followTo" ON followers USING btree ("to", to_notify);


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
-- Name: mentions_to_to_notify_idx; Type: INDEX; Schema: public; Owner: test_db; Tablespace: 
--

CREATE INDEX mentions_to_to_notify_idx ON mentions USING btree ("to", to_notify);


--
-- Name: pid; Type: INDEX; Schema: public; Owner: test_db; Tablespace: 
--

CREATE INDEX pid ON posts USING btree (pid, "to");


--
-- Name: posts_classification_lower_idx; Type: INDEX; Schema: public; Owner: test_db; Tablespace: 
--

CREATE INDEX posts_classification_lower_idx ON posts_classification USING btree (lower((tag)::text));


--
-- Name: whitelistTo; Type: INDEX; Schema: public; Owner: test_db; Tablespace: 
--

CREATE INDEX "whitelistTo" ON whitelist USING btree ("to");


--
-- Name: after_delete_blacklist; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER after_delete_blacklist AFTER DELETE ON blacklist FOR EACH ROW EXECUTE PROCEDURE after_delete_blacklist();


--
-- Name: after_delete_user; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER after_delete_user AFTER DELETE ON users FOR EACH ROW EXECUTE PROCEDURE after_delete_user();


--
-- Name: after_insert_blacklist; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER after_insert_blacklist AFTER INSERT ON blacklist FOR EACH ROW EXECUTE PROCEDURE after_insert_blacklist();


--
-- Name: after_insert_comment; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER after_insert_comment AFTER INSERT ON comments FOR EACH ROW EXECUTE PROCEDURE user_comment();


--
-- Name: after_insert_group_comment; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER after_insert_group_comment AFTER INSERT ON groups_comments FOR EACH ROW EXECUTE PROCEDURE group_comment();


--
-- Name: after_insert_group_post; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER after_insert_group_post AFTER INSERT ON groups_posts FOR EACH ROW EXECUTE PROCEDURE after_insert_group_post();


--
-- Name: after_insert_user; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER after_insert_user AFTER INSERT ON users FOR EACH ROW EXECUTE PROCEDURE after_insert_user();


--
-- Name: after_insert_user_post; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER after_insert_user_post AFTER INSERT ON posts FOR EACH ROW EXECUTE PROCEDURE after_insert_user_post();


--
-- Name: after_update_comment_message; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER after_update_comment_message AFTER UPDATE ON comments FOR EACH ROW WHEN ((new.message <> old.message)) EXECUTE PROCEDURE user_comment();


--
-- Name: after_update_groups_comment_message; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER after_update_groups_comment_message AFTER UPDATE ON groups_comments FOR EACH ROW WHEN ((new.message <> old.message)) EXECUTE PROCEDURE group_comment();


--
-- Name: after_update_groups_post_message; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER after_update_groups_post_message AFTER UPDATE ON groups_posts FOR EACH ROW WHEN ((new.message <> old.message)) EXECUTE PROCEDURE groups_post_update();


--
-- Name: after_update_post_message; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER after_update_post_message AFTER UPDATE ON posts FOR EACH ROW WHEN ((new.message <> old.message)) EXECUTE PROCEDURE post_update();


--
-- Name: after_update_userame; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER after_update_userame AFTER UPDATE ON users FOR EACH ROW WHEN (((old.username)::text <> (new.username)::text)) EXECUTE PROCEDURE after_update_userame();


--
-- Name: before_delete_user; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER before_delete_user BEFORE DELETE ON users FOR EACH ROW EXECUTE PROCEDURE before_delete_user();


--
-- Name: before_insert_comment; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER before_insert_comment BEFORE INSERT ON comments FOR EACH ROW EXECUTE PROCEDURE before_insert_comment();


--
-- Name: before_insert_comment_thumb; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER before_insert_comment_thumb BEFORE INSERT ON comment_thumbs FOR EACH ROW EXECUTE PROCEDURE before_insert_comment_thumb();


--
-- Name: before_insert_follower; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER before_insert_follower BEFORE INSERT ON followers FOR EACH ROW EXECUTE PROCEDURE before_insert_follower();


--
-- Name: before_insert_group_post; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER before_insert_group_post BEFORE INSERT ON groups_posts FOR EACH ROW EXECUTE PROCEDURE group_post_control();


--
-- Name: before_insert_group_post_lurker; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER before_insert_group_post_lurker BEFORE INSERT ON groups_lurkers FOR EACH ROW EXECUTE PROCEDURE before_insert_group_post_lurker();


--
-- Name: before_insert_groups_comment; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER before_insert_groups_comment BEFORE INSERT ON groups_comments FOR EACH ROW EXECUTE PROCEDURE before_insert_groups_comment();


--
-- Name: before_insert_groups_comment_thumb; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER before_insert_groups_comment_thumb BEFORE INSERT ON groups_comment_thumbs FOR EACH ROW EXECUTE PROCEDURE before_insert_groups_comment_thumb();


--
-- Name: before_insert_groups_follower; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER before_insert_groups_follower BEFORE INSERT ON groups_followers FOR EACH ROW EXECUTE PROCEDURE before_insert_groups_follower();


--
-- Name: before_insert_groups_member; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER before_insert_groups_member BEFORE INSERT ON groups_members FOR EACH ROW EXECUTE PROCEDURE before_insert_groups_member();


--
-- Name: before_insert_groups_thumb; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER before_insert_groups_thumb BEFORE INSERT ON groups_thumbs FOR EACH ROW EXECUTE PROCEDURE before_insert_groups_thumb();


--
-- Name: before_insert_pm; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER before_insert_pm BEFORE INSERT ON pms FOR EACH ROW EXECUTE PROCEDURE before_insert_pm();


--
-- Name: before_insert_post; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER before_insert_post BEFORE INSERT ON posts FOR EACH ROW EXECUTE PROCEDURE post_control();


--
-- Name: before_insert_thumb; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER before_insert_thumb BEFORE INSERT ON thumbs FOR EACH ROW EXECUTE PROCEDURE before_insert_thumb();


--
-- Name: before_insert_user_post_lurker; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER before_insert_user_post_lurker BEFORE INSERT ON lurkers FOR EACH ROW EXECUTE PROCEDURE before_insert_user_post_lurker();


--
-- Name: before_update_comment_message; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER before_update_comment_message BEFORE UPDATE ON comments FOR EACH ROW WHEN ((new.message <> old.message)) EXECUTE PROCEDURE user_comment_edit_control();


--
-- Name: before_update_group_comment_message; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER before_update_group_comment_message BEFORE UPDATE ON groups_comments FOR EACH ROW WHEN ((new.message <> old.message)) EXECUTE PROCEDURE group_comment_edit_control();


--
-- Name: before_update_group_post; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER before_update_group_post BEFORE UPDATE ON groups_posts FOR EACH ROW WHEN ((new.message <> old.message)) EXECUTE PROCEDURE group_post_control();


--
-- Name: before_update_post; Type: TRIGGER; Schema: public; Owner: test_db
--

CREATE TRIGGER before_update_post BEFORE UPDATE ON posts FOR EACH ROW WHEN ((new.message <> old.message)) EXECUTE PROCEDURE post_control();


--
-- Name: comments_revisions_hcid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY comments_revisions
    ADD CONSTRAINT comments_revisions_hcid_fkey FOREIGN KEY (hcid) REFERENCES comments(hcid) ON DELETE CASCADE;


--
-- Name: destfkusers; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY posts_no_notify
    ADD CONSTRAINT destfkusers FOREIGN KEY ("user") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: destgrofkusers; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_posts_no_notify
    ADD CONSTRAINT destgrofkusers FOREIGN KEY ("user") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: fkbanned; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY ban
    ADD CONSTRAINT fkbanned FOREIGN KEY ("user") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: fkfromfol; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY followers
    ADD CONSTRAINT fkfromfol FOREIGN KEY ("from") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: fkfromnonot; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_comments_notify
    ADD CONSTRAINT fkfromnonot FOREIGN KEY ("from") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: fkfromnonotproj; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_comments_notify
    ADD CONSTRAINT fkfromnonotproj FOREIGN KEY ("to") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: fkfromproj; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_posts
    ADD CONSTRAINT fkfromproj FOREIGN KEY ("from") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: fkfromprojnonot; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_comments_no_notify
    ADD CONSTRAINT fkfromprojnonot FOREIGN KEY ("from") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: fkfromusers; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY blacklist
    ADD CONSTRAINT fkfromusers FOREIGN KEY ("from") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: fkfromusersp; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_comments
    ADD CONSTRAINT fkfromusersp FOREIGN KEY ("from") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: fkfromuserswl; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY whitelist
    ADD CONSTRAINT fkfromuserswl FOREIGN KEY ("from") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: fkprofilesusers; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY profiles
    ADD CONSTRAINT fkprofilesusers FOREIGN KEY (counter) REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: fktofol; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY followers
    ADD CONSTRAINT fktofol FOREIGN KEY ("to") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: fktoproj; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_posts
    ADD CONSTRAINT fktoproj FOREIGN KEY ("to") REFERENCES groups(counter) ON DELETE CASCADE;


--
-- Name: fktoproject; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_comments
    ADD CONSTRAINT fktoproject FOREIGN KEY ("to") REFERENCES groups(counter) ON DELETE CASCADE;


--
-- Name: fktoprojnonot; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_comments_no_notify
    ADD CONSTRAINT fktoprojnonot FOREIGN KEY ("to") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: fktousers; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY blacklist
    ADD CONSTRAINT fktousers FOREIGN KEY ("to") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: fktouserswl; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY whitelist
    ADD CONSTRAINT fktouserswl FOREIGN KEY ("to") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: foregngrouphpid; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_posts_no_notify
    ADD CONSTRAINT foregngrouphpid FOREIGN KEY (hpid) REFERENCES groups_posts(hpid) ON DELETE CASCADE;


--
-- Name: foreignfromusers; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY comments
    ADD CONSTRAINT foreignfromusers FOREIGN KEY ("from") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: foreignhpid; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY posts_no_notify
    ADD CONSTRAINT foreignhpid FOREIGN KEY (hpid) REFERENCES posts(hpid) ON DELETE CASCADE;


--
-- Name: foreignhpid; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY comments_notify
    ADD CONSTRAINT foreignhpid FOREIGN KEY (hpid) REFERENCES posts(hpid) ON DELETE CASCADE;


--
-- Name: foreignkfromusers; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY posts
    ADD CONSTRAINT foreignkfromusers FOREIGN KEY ("from") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: foreignktousers; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY posts
    ADD CONSTRAINT foreignktousers FOREIGN KEY ("to") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: foreigntousers; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY comments
    ADD CONSTRAINT foreigntousers FOREIGN KEY ("to") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: forhpid; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY comments_no_notify
    ADD CONSTRAINT forhpid FOREIGN KEY (hpid) REFERENCES posts(hpid) ON DELETE CASCADE;


--
-- Name: forhpidbm; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY bookmarks
    ADD CONSTRAINT forhpidbm FOREIGN KEY (hpid) REFERENCES posts(hpid) ON DELETE CASCADE;


--
-- Name: forhpidbmgr; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_bookmarks
    ADD CONSTRAINT forhpidbmgr FOREIGN KEY (hpid) REFERENCES groups_posts(hpid) ON DELETE CASCADE;


--
-- Name: forkeyfromusers; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY comments_no_notify
    ADD CONSTRAINT forkeyfromusers FOREIGN KEY ("from") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: forkeyfromusersbmarks; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY bookmarks
    ADD CONSTRAINT forkeyfromusersbmarks FOREIGN KEY ("from") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: forkeyfromusersgrbmarks; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_bookmarks
    ADD CONSTRAINT forkeyfromusersgrbmarks FOREIGN KEY ("from") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: forkeytousers; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY comments_no_notify
    ADD CONSTRAINT forkeytousers FOREIGN KEY ("to") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: fornotfkeyfromusers; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY comments_notify
    ADD CONSTRAINT fornotfkeyfromusers FOREIGN KEY ("from") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: fornotfkeytousers; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY comments_notify
    ADD CONSTRAINT fornotfkeytousers FOREIGN KEY ("to") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: fromrefus; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY pms
    ADD CONSTRAINT fromrefus FOREIGN KEY ("from") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: grforkey; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_notify
    ADD CONSTRAINT grforkey FOREIGN KEY ("from") REFERENCES groups(counter) ON DELETE CASCADE;


--
-- Name: groupfkg; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_members
    ADD CONSTRAINT groupfkg FOREIGN KEY ("to") REFERENCES groups(counter) ON DELETE CASCADE;


--
-- Name: groupfollofkg; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_followers
    ADD CONSTRAINT groupfollofkg FOREIGN KEY ("to") REFERENCES groups(counter) ON DELETE CASCADE;


--
-- Name: groups_comments_revisions_hcid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_comments_revisions
    ADD CONSTRAINT groups_comments_revisions_hcid_fkey FOREIGN KEY (hcid) REFERENCES groups_comments(hcid) ON DELETE CASCADE;


--
-- Name: groups_notify_hpid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_notify
    ADD CONSTRAINT groups_notify_hpid_fkey FOREIGN KEY (hpid) REFERENCES groups_posts(hpid) ON DELETE CASCADE;


--
-- Name: groups_owners_from_fkey; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_owners
    ADD CONSTRAINT groups_owners_from_fkey FOREIGN KEY ("from") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: groups_owners_to_fkey; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_owners
    ADD CONSTRAINT groups_owners_to_fkey FOREIGN KEY ("to") REFERENCES groups(counter) ON DELETE CASCADE;


--
-- Name: groups_posts_revisions_hpid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_posts_revisions
    ADD CONSTRAINT groups_posts_revisions_hpid_fkey FOREIGN KEY (hpid) REFERENCES groups_posts(hpid) ON DELETE CASCADE;


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
    ADD CONSTRAINT hpidproj FOREIGN KEY (hpid) REFERENCES groups_posts(hpid) ON DELETE CASCADE;


--
-- Name: hpidprojnonot; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_comments_no_notify
    ADD CONSTRAINT hpidprojnonot FOREIGN KEY (hpid) REFERENCES groups_posts(hpid) ON DELETE CASCADE;


--
-- Name: hpidref; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY comments
    ADD CONSTRAINT hpidref FOREIGN KEY (hpid) REFERENCES posts(hpid) ON DELETE CASCADE;


--
-- Name: hpidthumbs; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY thumbs
    ADD CONSTRAINT hpidthumbs FOREIGN KEY (hpid) REFERENCES posts(hpid) ON DELETE CASCADE;


--
-- Name: mentions_from_fkey; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY mentions
    ADD CONSTRAINT mentions_from_fkey FOREIGN KEY ("from") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: mentions_g_hpid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY mentions
    ADD CONSTRAINT mentions_g_hpid_fkey FOREIGN KEY (g_hpid) REFERENCES groups_posts(hpid) ON DELETE CASCADE;


--
-- Name: mentions_to_fkey; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY mentions
    ADD CONSTRAINT mentions_to_fkey FOREIGN KEY ("to") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: mentions_u_hpid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY mentions
    ADD CONSTRAINT mentions_u_hpid_fkey FOREIGN KEY (u_hpid) REFERENCES posts(hpid) ON DELETE CASCADE;


--
-- Name: posts_classification_g_hpid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY posts_classification
    ADD CONSTRAINT posts_classification_g_hpid_fkey FOREIGN KEY (g_hpid) REFERENCES groups_posts(hpid) ON DELETE CASCADE;


--
-- Name: posts_classification_u_hpid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY posts_classification
    ADD CONSTRAINT posts_classification_u_hpid_fkey FOREIGN KEY (u_hpid) REFERENCES posts(hpid) ON DELETE CASCADE;


--
-- Name: posts_notify_from_fkey; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY posts_notify
    ADD CONSTRAINT posts_notify_from_fkey FOREIGN KEY ("from") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: posts_notify_hpid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY posts_notify
    ADD CONSTRAINT posts_notify_hpid_fkey FOREIGN KEY (hpid) REFERENCES posts(hpid) ON DELETE CASCADE;


--
-- Name: posts_notify_to_fkey; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY posts_notify
    ADD CONSTRAINT posts_notify_to_fkey FOREIGN KEY ("to") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: posts_revisions_hpid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY posts_revisions
    ADD CONSTRAINT posts_revisions_hpid_fkey FOREIGN KEY (hpid) REFERENCES posts(hpid) ON DELETE CASCADE;


--
-- Name: refhipdgl; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_lurkers
    ADD CONSTRAINT refhipdgl FOREIGN KEY (hpid) REFERENCES groups_posts(hpid) ON DELETE CASCADE;


--
-- Name: refhipdl; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY lurkers
    ADD CONSTRAINT refhipdl FOREIGN KEY (hpid) REFERENCES posts(hpid) ON DELETE CASCADE;


--
-- Name: reftogroupshpid; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_comments_notify
    ADD CONSTRAINT reftogroupshpid FOREIGN KEY (hpid) REFERENCES groups_posts(hpid) ON DELETE CASCADE;


--
-- Name: refusergl; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_lurkers
    ADD CONSTRAINT refusergl FOREIGN KEY ("from") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: refuserl; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY lurkers
    ADD CONSTRAINT refuserl FOREIGN KEY ("from") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: reset_requests_to_fkey; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY reset_requests
    ADD CONSTRAINT reset_requests_to_fkey FOREIGN KEY ("to") REFERENCES users(counter);


--
-- Name: special_groups_counter_fkey; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY special_groups
    ADD CONSTRAINT special_groups_counter_fkey FOREIGN KEY (counter) REFERENCES groups(counter) ON DELETE CASCADE;


--
-- Name: special_users_counter_fkey; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY special_users
    ADD CONSTRAINT special_users_counter_fkey FOREIGN KEY (counter) REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: toCommentThumbFk; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY comment_thumbs
    ADD CONSTRAINT "toCommentThumbFk" FOREIGN KEY ("to") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: toGCommentThumbFk; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_comment_thumbs
    ADD CONSTRAINT "toGCommentThumbFk" FOREIGN KEY ("to") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: toGLurkFk; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_lurkers
    ADD CONSTRAINT "toGLurkFk" FOREIGN KEY ("to") REFERENCES groups(counter) ON DELETE CASCADE;


--
-- Name: toGThumbFk; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_thumbs
    ADD CONSTRAINT "toGThumbFk" FOREIGN KEY ("to") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: toLurkFk; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY lurkers
    ADD CONSTRAINT "toLurkFk" FOREIGN KEY ("to") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: toThumbFk; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY thumbs
    ADD CONSTRAINT "toThumbFk" FOREIGN KEY ("to") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: torefus; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY pms
    ADD CONSTRAINT torefus FOREIGN KEY ("to") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: userfkg; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_members
    ADD CONSTRAINT userfkg FOREIGN KEY ("from") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: userfollofkg; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_followers
    ADD CONSTRAINT userfollofkg FOREIGN KEY ("from") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: usergthumbs; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_thumbs
    ADD CONSTRAINT usergthumbs FOREIGN KEY ("from") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: usergthumbs; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_comment_thumbs
    ADD CONSTRAINT usergthumbs FOREIGN KEY ("from") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: userthumbs; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY thumbs
    ADD CONSTRAINT userthumbs FOREIGN KEY ("from") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: userthumbs; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY comment_thumbs
    ADD CONSTRAINT userthumbs FOREIGN KEY ("from") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: usetoforkey; Type: FK CONSTRAINT; Schema: public; Owner: test_db
--

ALTER TABLE ONLY groups_notify
    ADD CONSTRAINT usetoforkey FOREIGN KEY ("to") REFERENCES users(counter) ON DELETE CASCADE;


--
-- Name: public; Type: ACL; Schema: -; Owner: %%postgres%%
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM %%postgres%%;
GRANT ALL ON SCHEMA public TO %%postgres%%;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

