-- =====================================================================================
--  Hader for Oracle APEX (native): the address the terminals send to, served by ORDS.
--
--  Run as the schema that holds the HDR_* objects. Terminals always call /iclock/<name>,
--  so ORDS must answer that path at the root of a listener the terminals can reach over HTTP
--  (see the guide: a second ORDS listener with context path "/", or a web-server rule
--  /iclock/* -> /ords/iclock/*). The schema's address segment is therefore "iclock".
--  A schema REST-enabled already (an HR schema with its own REST clients) keeps its address and its
--  settings: the module goes under its own segment (/ords/<that segment>/...), and the web-server rule
--  points there instead. Changing that segment is the institution's own decision, made by hand.
-- =====================================================================================
DECLARE
  TYPE t_list IS TABLE OF VARCHAR2(30);
  l_paths t_list := t_list('cdata', 'getrequest', 'devicecmd', 'querydata', 'ping', 'rtdata', 'registry', 'push', 'fdata');
  l_path  VARCHAR2(40);
  l_on    NUMBER := 0;
BEGIN
  BEGIN
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM USER_ORDS_SCHEMAS' INTO l_on;
  EXCEPTION WHEN OTHERS THEN
    l_on := 0;
  END;
  IF l_on = 0 THEN
    -- the module's handlers answer whatever this says; the schema's metadata catalogue stays behind sign-in
    ORDS.ENABLE_SCHEMA(p_enabled => TRUE, p_schema => USER, p_url_mapping_type => 'BASE_PATH',
                       p_url_mapping_pattern => 'iclock', p_auto_rest_auth => TRUE);
  ELSE
    DBMS_OUTPUT.PUT_LINE('This schema was REST-enabled already: its address is kept; the terminals'' rule points to it.');
  END IF;
  ORDS.DEFINE_MODULE(p_module_name => 'hader.iclock', p_base_path => '/', p_items_per_page => 0,
                     p_status => 'PUBLISHED', p_comments => 'Hader: biometric terminals (push protocol)');
  FOR i IN 1 .. l_paths.COUNT LOOP
    FOR j IN 1 .. 2 LOOP
      l_path := l_paths(i) || CASE WHEN j = 2 THEN '.aspx' END;   -- older firmware appends .aspx
      ORDS.DEFINE_TEMPLATE(p_module_name => 'hader.iclock', p_pattern => l_path);
      ORDS.DEFINE_HANDLER(p_module_name => 'hader.iclock', p_pattern => l_path, p_method => 'GET',
                          p_source_type => ORDS.SOURCE_TYPE_PLSQL,
                          p_source => 'BEGIN HDR_ADMS.handle(''' || l_path || ''', ''GET''); END;');
      ORDS.DEFINE_HANDLER(p_module_name => 'hader.iclock', p_pattern => l_path, p_method => 'POST',
                          p_source_type => ORDS.SOURCE_TYPE_PLSQL,
                          p_source => 'BEGIN HDR_ADMS.handle(''' || l_path || ''', ''POST'', :body); END;');
    END LOOP;
  END LOOP;
  COMMIT;
END;
/
