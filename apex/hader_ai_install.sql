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
cf97 3e52
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
1AyPDuTueWHgCtAc38ytVq+NBrC1HrUdlQj17Q==
/
