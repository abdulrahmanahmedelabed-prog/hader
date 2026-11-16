-- =====================================================================================
--  Hader AI for Oracle APEX - the AI services of APEX 24 and later, for APEX 19.2 and later (Oracle 11g and later).
--  Run it in the schema of your APEX application (SQL*Plus, SQL Developer, or SQL Workshop > SQL Scripts), then
--  import the Hader AI plug-ins: Hader AI Services, Hader AI Assistant, Hader AI Generate Text. Safe to run again.
--  Already in hader_apex_install.sql (Hader for Oracle APEX): this file is for Hader AI alone.
--  Remove it with: DROP PACKAGE HDR_AI; DROP TABLE HDR_AI_SERVICES PURGE; DROP SEQUENCE HDR_AI_SEQ;
-- =====================================================================================
-- Hader AI for Oracle APEX: the AI services (the APEX 24+ "Generative AI Services" of APEX 19.2 and later).
-- One row a service: its provider, address and model, and where its calls are made from: the user's browser
-- (no network permission or wallet in the database: Oracle 11g and any server) or the database (the key never
-- leaves it: the database must reach the provider over HTTPS). The key is written here and never read back by a
-- page, but by the browser of a user allowed to use the assistant when the service is called from the browser.
-- Standalone: the same tables with or without the rest of Hader for Oracle APEX; run again safely.
DECLARE
  n NUMBER;
BEGIN
  SELECT COUNT(*) INTO n FROM user_tables WHERE table_name = 'HDR_AI_SERVICES';
  IF n = 0 THEN
    EXECUTE IMMEDIATE q'[
      CREATE TABLE HDR_AI_SERVICES (
        SERVICE_ID  NUMBER          NOT NULL,
        STATIC_ID   VARCHAR2(100)   NOT NULL,                 -- the name pages and code use
        NAME        VARCHAR2(200)   NOT NULL,
        PROVIDER    VARCHAR2(20)    NOT NULL,                 -- GEMINI / OPENAI / ANTHROPIC / COMPATIBLE
        BASE_URL    VARCHAR2(400)   NOT NULL,
        MODEL       VARCHAR2(200)   NOT NULL,
        CALL_FROM   VARCHAR2(10)    DEFAULT 'BROWSER' NOT NULL, -- BROWSER / DATABASE
        CREDENTIAL  VARCHAR2(255),                            -- DATABASE: a Web Credential for AI (static id AI_...)
        API_KEY     VARCHAR2(4000),                           -- written, never shown again
        MAX_TOKENS  NUMBER,
        IS_DEFAULT  VARCHAR2(1)     DEFAULT 'N' NOT NULL,
        ENABLED     VARCHAR2(1)     DEFAULT 'Y' NOT NULL,
        TESTED_AT   DATE,
        TEST_RESULT VARCHAR2(400),
        UPDATED_BY  VARCHAR2(255),
        UPDATED_AT  DATE            DEFAULT SYSDATE NOT NULL,
        PER_MINUTE  NUMBER,                                   -- DATABASE: one user's requests a minute (NULL: 20)
        CONSTRAINT HDR_AI_SERVICES_PK PRIMARY KEY (SERVICE_ID),
        CONSTRAINT HDR_AI_SERVICES_UK UNIQUE (STATIC_ID),
        CONSTRAINT HDR_AI_SERVICES_P CHECK (PROVIDER IN ('GEMINI', 'OPENAI', 'ANTHROPIC', 'COMPATIBLE')),
        CONSTRAINT HDR_AI_SERVICES_C CHECK (CALL_FROM IN ('BROWSER', 'DATABASE')))]';
  END IF;
  SELECT COUNT(*) INTO n FROM user_tab_columns WHERE table_name = 'HDR_AI_SERVICES' AND column_name = 'PER_MINUTE';
  IF n = 0 THEN
    EXECUTE IMMEDIATE 'ALTER TABLE HDR_AI_SERVICES ADD (PER_MINUTE NUMBER)';
  END IF;
  SELECT COUNT(*) INTO n FROM user_sequences WHERE sequence_name = 'HDR_AI_SEQ';
  IF n = 0 THEN
    EXECUTE IMMEDIATE 'CREATE SEQUENCE HDR_AI_SEQ NOCACHE';
  END IF;
  -- each user's requests and questions about the data of the last minutes (how many a minute: HDR_AI)
  SELECT COUNT(*) INTO n FROM user_tables WHERE table_name = 'HDR_AI_CALLS';
  IF n = 0 THEN
    EXECUTE IMMEDIATE q'[
      CREATE TABLE HDR_AI_CALLS (
        USER_NAME VARCHAR2(255) NOT NULL,
        KIND      VARCHAR2(1)   NOT NULL,                     -- R a request to a provider, L a question about the data
        CALLED_AT DATE          DEFAULT SYSDATE NOT NULL)]';
    EXECUTE IMMEDIATE 'CREATE INDEX HDR_AI_CALLS_I ON HDR_AI_CALLS (USER_NAME, KIND, CALLED_AT)';
    EXECUTE IMMEDIATE 'CREATE INDEX HDR_AI_CALLS_T ON HDR_AI_CALLS (CALLED_AT)';
  END IF;
END;
/

CREATE OR REPLACE PACKAGE HDR_AI AS
  -- Hader AI for Oracle APEX: AI services and an assistant for APEX 19.2 and later (as the Generative AI services of
  -- APEX 24 and later). Standalone: it compiles and works with or without the rest of Hader for Oracle APEX, on
  -- Oracle 11g and later; nothing of APEX is named at compile time (APEX_WEB_SERVICE and APEX_JSON are called by name).
  --
  -- A service is called from the user's browser (the database needs no network permission and no wallet; the key
  -- reaches the browsers of the users allowed to use it) or from the database (the key never leaves it; the database
  -- must reach the provider over HTTPS). The browser builds each request and reads each answer (hader-ai.js); the
  -- database keeps the services and the key, relays a request when the service is called from the database (rebuilt
  -- here: the service's own model, its tokens at most, the provider's chat and function tools only), and answers the
  -- assistant's questions about the data (tool) with the signed-in user's own permissions.
  --
  -- Who: in APEX always the signed-in user (whatever is passed), never a public one; outside APEX the schema's owner
  -- names the user, and nobody else may call it.
  -- Permissions: with Hader for Oracle APEX in the schema (HDR_UI), its accounts: ai.use to use a service and
  -- system.admin to change them; without it (Hader AI alone) the application decides (the page's and the region's
  -- authorization; the services region requires its own scheme).
  c_version CONSTANT VARCHAR2(10) := '1.0';
  -- the Web Credentials a service may use: their static id starts so (AI_OPENAI, AI_GEMINI): the workspace's other
  -- credentials are never sent to the address of an AI service. With APEX 21.2 and later the credential's Valid for
  -- URLs must also name the service's address.
  c_credential_prefix CONSTANT VARCHAR2(10) := 'AI_';
  -- one user's requests a minute to a service called from the database (when the service sets none), and questions
  -- about the data a minute
  c_requests_per_minute CONSTANT PLS_INTEGER := 20;
  c_lookups_per_minute  CONSTANT PLS_INTEGER := 120;
  -- the tokens of an answer when the service sets none, and how long one request to a provider may take (seconds)
  c_max_tokens CONSTANT PLS_INTEGER := 8192;
  c_timeout    CONSTANT PLS_INTEGER := 60;

  FUNCTION mode_ RETURN VARCHAR2;                                              -- HADER / APP
  FUNCTION ready RETURN VARCHAR2;                                              -- Y: an enabled service
  FUNCTION may_use (p_user IN VARCHAR2 DEFAULT NULL) RETURN VARCHAR2;          -- Y / N
  FUNCTION may_admin (p_user IN VARCHAR2 DEFAULT NULL) RETURN VARCHAR2;        -- Y / N

  -- the services for the page that manages them: everything but the keys (only whether one is kept, and its end)
  FUNCTION services (p_user IN VARCHAR2 DEFAULT NULL) RETURN CLOB;
  -- p_id NULL: a new one. p_key NULL: the key kept stays; '-': no key. A key or a credential stays with the address
  -- it was given for: a change of the provider or of the address (scheme, host and port) removes the key kept and
  -- the credential kept (p_credential_again 'Y': chosen again for the new address), and so does calling a service
  -- from the browser that was called from the database (its key was given never to leave it). Returns the id.
  FUNCTION save_service (p_user IN VARCHAR2, p_id IN NUMBER, p_static IN VARCHAR2, p_name IN VARCHAR2,
                         p_provider IN VARCHAR2, p_url IN VARCHAR2, p_model IN VARCHAR2, p_call IN VARCHAR2,
                         p_credential IN VARCHAR2, p_key IN VARCHAR2, p_tokens IN NUMBER, p_default IN VARCHAR2,
                         p_enabled IN VARCHAR2, p_per_minute IN NUMBER DEFAULT NULL,
                         p_credential_again IN VARCHAR2 DEFAULT 'N') RETURN NUMBER;
  PROCEDURE drop_service (p_user IN VARCHAR2, p_id IN NUMBER);
  PROCEDURE tested (p_user IN VARCHAR2, p_id IN NUMBER, p_result IN VARCHAR2);

  -- one service for a call (by its static id; NULL: the default one): its provider, address, model, where it is
  -- called from, and its key when it is called from the browser. An enabled one; p_test 'Y': a system
  -- administrator's test on the services page (a disabled one too)
  FUNCTION service (p_user IN VARCHAR2, p_static IN VARCHAR2, p_test IN VARCHAR2 DEFAULT 'N') RETURN CLOB;
  -- a request of a service called from the database (by its static id, as service): rebuilt, posted to the service's
  -- own address with its key, and its answer as the page reads it: the text and the tool calls, or the error
  FUNCTION relay (p_user IN VARCHAR2, p_static IN VARCHAR2, p_body IN CLOB, p_test IN VARCHAR2 DEFAULT 'N') RETURN CLOB;

  -- what the assistant may ask about the data here (comma separated): attendance, terminals; empty: nothing
  FUNCTION tools (p_user IN VARCHAR2 DEFAULT NULL) RETURN VARCHAR2;
  -- one question about the data, as JSON, with the user's own permissions (a user who does not see the attendance
  -- sees only themself): day, people, find, employee, totals, terminals
  FUNCTION tool (p_user IN VARCHAR2, p_name IN VARCHAR2, p_a1 IN VARCHAR2 DEFAULT NULL, p_a2 IN VARCHAR2 DEFAULT NULL,
                 p_a3 IN VARCHAR2 DEFAULT NULL, p_a4 IN VARCHAR2 DEFAULT NULL, p_a5 IN VARCHAR2 DEFAULT NULL) RETURN CLOB;

  -- for PL/SQL (as APEX_AI.GENERATE): one answer of a service called from the database, in APEX for a user allowed
  -- to use it, outside APEX for the schema's owner only
  FUNCTION generate (p_prompt IN CLOB, p_system IN CLOB DEFAULT NULL, p_service IN VARCHAR2 DEFAULT NULL) RETURN CLOB;
END HDR_AI;
/

CREATE OR REPLACE PACKAGE BODY HDR_AI wrapped 
a000000
369
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
abcd
b
d12e 3ec0
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
Wg==
/
