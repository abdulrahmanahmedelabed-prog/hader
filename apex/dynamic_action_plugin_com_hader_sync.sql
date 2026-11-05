prompt --application/set_environment
set define off verify off feedback off
whenever sqlerror exit sql.sqlcode rollback
--------------------------------------------------------------------------------
--
-- ORACLE Application Express (APEX) export file
--
-- You should run the script connected to SQL*Plus as the Oracle user
-- APEX_190200 or as the owner (parsing schema) of the application.
--
-- NOTE: Calls to apex_application_install override the defaults below.
--
--------------------------------------------------------------------------------
begin
wwv_flow_api.import_begin (
 p_version_yyyy_mm_dd=>'2019.10.04'
,p_release=>'19.2.0.00.18'
,p_default_workspace_id=>1
,p_default_application_id=>100
,p_default_id_offset=>0
,p_default_owner=>'HADER'
);
end;
/

prompt APPLICATION 100 - Hader
--
-- Application Export:
--   Application:     100
--   Name:            Hader
--   Exported By:     HADER
--   Flashback:       0
--   Export Type:     Component Export
--   Manifest
--     PLUGIN: COM.HADER.SYNC
--   Manifest End
--   Version:         19.2.0.00.18
--   Instance ID:     1
--

prompt --application/shared_components/plugins/dynamic_action/com_hader_sync
begin
wwv_flow_api.create_plugin(
 p_id=>wwv_flow_api.id(91734400000001)
,p_plugin_type=>'DYNAMIC ACTION'
,p_name=>'COM.HADER.SYNC'
,p_display_name=>'Hader Sync (حاضر - مزامنة)'
,p_category=>'EXECUTE'
,p_supported_ui_types=>'DESKTOP:JQM_SMARTPHONE'
,p_javascript_file_urls=>'#PLUGIN_FILES#hader-sync.js'
,p_plsql_code=>wwv_flow_string.join(wwv_flow_t_varchar2(
'-- Hader sync (dynamic action plug-in). APEX 19.2 and later, Oracle 11g and later.',
'-- Writes a request into HADER_REQUESTS; Hader picks it up within seconds and writes the outcome back.',
'-- Hader for Oracle APEX (native, no Hader program): the request is started at once in the database',
'-- (HDR_JOBS.start_request; grant EXECUTE on HDR_JOBS to the parsing schema).',
'',
'function obj (p_action in apex_plugin.t_dynamic_action, p_name in varchar2) return varchar2 is',
'  l_owner varchar2(200) := trim(p_action.attribute_01);',
'begin',
'  if l_owner is null then',
'    return p_name;',
'  end if;',
'  if not regexp_like(l_owner, ''^[A-Za-z][A-Za-z0-9_$#]{0,29}(@[A-Za-z][A-Za-z0-9_$#.]{0,120})?$'') then',
'    raise_application_error(-20001, ''Hader sync: invalid owner '' || l_owner);',
'  end if;',
'  if instr(l_owner, ''@'') > 0 then   -- OWNER@DBLINK',
'    return substr(l_owner, 1, instr(l_owner, ''@'') - 1) || ''.'' || p_name || substr(l_owner, instr(l_owner, ''@''));',
'  end if;',
'  return l_owner || ''.'' || p_name;',
'end obj;',
'',
'function item_date (p_item in varchar2) return date is',
'  l_v varchar2(100);',
'begin',
'  if p_item is null then',
'    return null;',
'  end if;',
'  l_v := trim(v(p_item));',
'  if l_v is null then',
'    return null;',
'  end if;',
'  begin',
'    return trunc(to_date(l_v));   -- APEX sets the session date format to the application''s',
'  exception when others then',
'    return trunc(to_date(substr(l_v, 1, 10), ''YYYY-MM-DD''));',
'  end;',
'end item_date;',
'',
'function render (',
'  p_dynamic_action in apex_plugin.t_dynamic_action,',
'  p_plugin         in apex_plugin.t_plugin )',
'  return apex_plugin.t_dynamic_action_render_result',
'is',
'  l_result apex_plugin.t_dynamic_action_render_result;',
'  l_items  varchar2(4000);',
'begin',
'  for i in 1 .. 3 loop',
'    declare',
'      l_item varchar2(255) := case i when 1 then p_dynamic_action.attribute_03',
'                                     when 2 then p_dynamic_action.attribute_04',
'                                     else p_dynamic_action.attribute_05 end;',
'    begin',
'      if l_item is not null then',
'        l_items := l_items || case when l_items is not null then '','' end || l_item;',
'      end if;',
'    end;',
'  end loop;',
'  l_result.javascript_function := ''hdrSync.run'';',
'  l_result.ajax_identifier     := apex_plugin.get_ajax_identifier;',
'  l_result.attribute_01        := l_items;',
'  l_result.attribute_02        := nvl(p_dynamic_action.attribute_06, ''90'');   -- seconds to wait',
'  l_result.attribute_03        := nvl(p_dynamic_action.attribute_07, ''Y'');    -- show the outcome',
'  l_result.attribute_04        := nvl(p_dynamic_action.attribute_08, ''AUTO''); -- language',
'  l_result.attribute_05        := nvl(p_dynamic_action.attribute_02, ''SYNC'');',
'  return l_result;',
'end render;',
'',
'-- who may ask: in Hader for Oracle APEX the signed-in user''s permission for the request (HDR_UI.may); with the Hader',
'-- program alone (no HDR_UI here) the application''s own authorization of the page decides',
'function allowed (p_dynamic_action in apex_plugin.t_dynamic_action, p_kind in varchar2) return boolean is',
'  l_may varchar2(1);',
'begin',
'  execute immediate ''begin :m := '' || obj(p_dynamic_action, ''HDR_UI'') || ''.may(:u, :p); end;''',
'    using out l_may, in v(''APP_USER''),',
'          in case p_kind when ''RECALC'' then ''attendance.edit'' when ''EMPLOYEES'' then ''personnel.edit'' else ''attendance.view'' end;',
'  return l_may = ''Y'';',
'exception when others then',
'  return sqlcode in (-6550, -942, -4043, -201);',
'end allowed;',
'',
'function ajax (',
'  p_dynamic_action in apex_plugin.t_dynamic_action,',
'  p_plugin         in apex_plugin.t_plugin )',
'  return apex_plugin.t_dynamic_action_ajax_result',
'is',
'  l_kind   varchar2(20) := nvl(p_dynamic_action.attribute_02, ''SYNC'');',
'  l_id     raw(16);',
'  l_status varchar2(10);',
'  l_msg    varchar2(4000);',
'  l_wait   number;',
'  l_emp    varchar2(30);',
'  l_from   date;',
'  l_to     date;',
'begin',
'  apex_json.open_object;',
'  if apex_application.g_x01 = ''ASK'' and not allowed(p_dynamic_action, l_kind) then',
'    raise_application_error(-20699, ''not allowed'');',
'  elsif apex_application.g_x01 = ''ASK'' then',
'    l_emp  := case when p_dynamic_action.attribute_03 is not null then substr(trim(v(p_dynamic_action.attribute_03)), 1, 30) end;',
'    l_from := item_date(p_dynamic_action.attribute_04);',
'    l_to   := item_date(p_dynamic_action.attribute_05);',
'    -- the same request already waiting: a second press joins it',
'    begin',
'      execute immediate ''select req_id from '' || obj(p_dynamic_action, ''HADER_REQUESTS'') ||',
'        '' where kind = :k and status = ''''NEW'''' and nvl(emp_code, ''''~'''') = nvl(:e, ''''~'''')'' ||',
'        '' and nvl(date_from, date ''''1900-01-01'''') = nvl(:f, date ''''1900-01-01'''')'' ||',
'        '' and nvl(date_to, date ''''1900-01-01'''') = nvl(:t, date ''''1900-01-01'''') and rownum = 1''',
'        into l_id using l_kind, l_emp, l_from, l_to;',
'    exception when no_data_found then',
'      execute immediate ''insert into '' || obj(p_dynamic_action, ''HADER_REQUESTS'') ||',
'        '' (kind, emp_code, date_from, date_to, requested_by) values (:k, :e, :f, :t, :u) returning req_id into :id''',
'        using l_kind, l_emp, l_from, l_to, substr(v(''APP_USER''), 1, 100)',
'        returning into l_id;',
'      commit;',
'      begin   -- native: run it now; with the Hader program there is no HDR_JOBS and Hader takes it',
'        execute immediate ''begin '' || obj(p_dynamic_action, ''HDR_JOBS'') || ''.start_request(:id); end;'' using l_id;',
'      exception when others then',
'        null;',
'      end;',
'    end;',
'    apex_json.write(''id'', rawtohex(l_id));',
'  else',
'    -- how is it going?',
'    execute immediate ''select status, message, round((sysdate - requested_at) * 86400) from '' ||',
'      obj(p_dynamic_action, ''HADER_REQUESTS'') || '' where req_id = hextoraw(:id) and kind = :k''   -- this action''s own kind only',
'      into l_status, l_msg, l_wait using apex_application.g_x02, l_kind;',
'    apex_json.write(''status'', l_status);',
'    apex_json.write(''message'', l_msg);',
'    apex_json.write(''waited'', l_wait);',
'  end if;',
'  apex_json.close_object;',
'  return null;',
'exception when others then',
'  apex_json.free_output;',
'  sys.htp.init;   -- drop the half-written JSON',
'  apex_json.open_object;',
'  apex_debug.error(''Hader sync: %s'', sqlerrm);',
'  apex_json.write(''failure'', case when sqlcode = -20699 then ''Not allowed''   -- not ''error'': apex.server takes that one',
'    when sqlcode = -942 then ''Run "Create the link objects" in Hader, then grant SELECT, INSERT on HADER_REQUESTS''',
'    when sqlcode between -20999 and -20000 then regexp_replace(sqlerrm, ''^ORA-[0-9]+: '')     -- Hader''s own words',
'    else ''The request failed (the page''''s debug log has the detail)'' end);',
'  apex_json.close_object;',
'  return null;',
'end ajax;'))
,p_api_version=>1
,p_render_function=>'render'
,p_ajax_function=>'ajax'
,p_standard_attributes=>'STOP_EXECUTION_ON_ERROR:WAIT_FOR_RESULT'
,p_substitute_attributes=>true
,p_subscribe_plugin_settings=>true
,p_help_text=>'Asks Hader to sync now and waits for the answer: new punches from the terminals, today''s results, employees from HR, leave, or a recalculation of a period. Hader reads the request from HADER_REQUESTS within seconds — nothing has to reach Hader from the database. Turn on "Wait for Result" and add a Refresh action after it to show the new data. Fires the events hadersyncdone / hadersyncfailed on the document.'
,p_version_identifier=>'1.3'
,p_files_version=>82293
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(91734400000002)
,p_plugin_id=>wwv_flow_api.id(91734400000001)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>1
,p_display_sequence=>10
,p_prompt=>'Owner of the Hader tables'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_display_length=>30
,p_max_length=>160
,p_is_translatable=>false
,p_help_text=>'Schema that owns the Hader tables and views (e.g. HADER_LINK). Empty = the application''s parsing schema. Through a database link: HADER_LINK@HRDB.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(91734400000003)
,p_plugin_id=>wwv_flow_api.id(91734400000001)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>2
,p_display_sequence=>20
,p_prompt=>'Request'
,p_attribute_type=>'SELECT LIST'
,p_is_required=>true
,p_default_value=>'SYNC'
,p_is_translatable=>false
,p_lov_type=>'STATIC'
,p_help_text=>'Sync: new punches from the terminals, then the results of the period (default today). Punches only. Employees: read employees and departments from HR now (new people go onto the terminals). Leave: read leave now and recalculate. Recalculate: send the results of the period again (e.g. after approving old leave).'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(91734400000004)
,p_plugin_attribute_id=>wwv_flow_api.id(91734400000003)
,p_display_sequence=>10
,p_display_value=>'Sync punches and today''s results'
,p_return_value=>'SYNC'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(91734400000005)
,p_plugin_attribute_id=>wwv_flow_api.id(91734400000003)
,p_display_sequence=>20
,p_display_value=>'Punches only'
,p_return_value=>'PUNCHES'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(91734400000006)
,p_plugin_attribute_id=>wwv_flow_api.id(91734400000003)
,p_display_sequence=>30
,p_display_value=>'Employees and departments from HR'
,p_return_value=>'EMPLOYEES'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(91734400000007)
,p_plugin_attribute_id=>wwv_flow_api.id(91734400000003)
,p_display_sequence=>40
,p_display_value=>'Leave from HR'
,p_return_value=>'LEAVES'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(91734400000008)
,p_plugin_attribute_id=>wwv_flow_api.id(91734400000003)
,p_display_sequence=>50
,p_display_value=>'Recalculate a period'
,p_return_value=>'RECALC'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(91734400000009)
,p_plugin_id=>wwv_flow_api.id(91734400000001)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>3
,p_display_sequence=>30
,p_prompt=>'Employee item'
,p_attribute_type=>'PAGE ITEM'
,p_is_required=>false
,p_is_translatable=>false
,p_help_text=>'Optional: only this employee (EMP_CODE) — for Sync and Recalculate.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(91734400000010)
,p_plugin_id=>wwv_flow_api.id(91734400000001)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>4
,p_display_sequence=>40
,p_prompt=>'From date item'
,p_attribute_type=>'PAGE ITEM'
,p_is_required=>false
,p_is_translatable=>false
,p_help_text=>'Optional: first day of the period (default today).'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(91734400000011)
,p_plugin_id=>wwv_flow_api.id(91734400000001)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>5
,p_display_sequence=>50
,p_prompt=>'To date item'
,p_attribute_type=>'PAGE ITEM'
,p_is_required=>false
,p_is_translatable=>false
,p_help_text=>'Optional: last day of the period (default the first day).'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(91734400000012)
,p_plugin_id=>wwv_flow_api.id(91734400000001)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>6
,p_display_sequence=>60
,p_prompt=>'Wait up to (seconds)'
,p_attribute_type=>'INTEGER'
,p_is_required=>true
,p_default_value=>'90'
,p_display_length=>4
,p_is_translatable=>false
,p_help_text=>'How long the page waits for Hader''s answer.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(91734400000013)
,p_plugin_id=>wwv_flow_api.id(91734400000001)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>7
,p_display_sequence=>70
,p_prompt=>'Show the outcome'
,p_attribute_type=>'CHECKBOX'
,p_is_required=>false
,p_default_value=>'Y'
,p_is_translatable=>false
,p_help_text=>'A success or error message at the top of the page.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(91734400000014)
,p_plugin_id=>wwv_flow_api.id(91734400000001)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>8
,p_display_sequence=>80
,p_prompt=>'Language'
,p_attribute_type=>'SELECT LIST'
,p_is_required=>true
,p_default_value=>'AUTO'
,p_is_translatable=>false
,p_lov_type=>'STATIC'
,p_help_text=>'Automatic follows the application language.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(91734400000015)
,p_plugin_attribute_id=>wwv_flow_api.id(91734400000014)
,p_display_sequence=>10
,p_display_value=>'Automatic'
,p_return_value=>'AUTO'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(91734400000016)
,p_plugin_attribute_id=>wwv_flow_api.id(91734400000014)
,p_display_sequence=>20
,p_display_value=>'العربية'
,p_return_value=>'AR'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(91734400000017)
,p_plugin_attribute_id=>wwv_flow_api.id(91734400000014)
,p_display_sequence=>30
,p_display_value=>'English'
,p_return_value=>'EN'
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '2F2A2048616465722073796E6320E2809420415045582064796E616D696320616374696F6E20706C75672D696E2E2041736B7320486164657220666F7220612073796E6320616E6420776169747320666F722074686520616E737765722E202A2F0A7769';
wwv_flow_api.g_varchar2_table(2) := '6E646F772E68647253796E63203D2077696E646F772E68647253796E63207C7C202866756E6374696F6E202829207B0A20202775736520737472696374273B0A202076617220545854203D207B0A2020202061723A207B20627573793A2027D8ACD8A7D8';
wwv_flow_api.g_varchar2_table(3) := 'B1D98D20D8A7D984D985D8B2D8A7D985D986D8A920D985D8B920D8ADD8A7D8B6D8B1E280A6272C20646F6E653A2027D8AAD985D8AA20D8A7D984D985D8B2D8A7D985D986D8A920D985D8B920D8ADD8A7D8B6D8B1272C206661696C65643A2027D8AAD8B9';
wwv_flow_api.g_varchar2_table(4) := 'D8B0D991D8B1D8AA20D8A7D984D985D8B2D8A7D985D986D8A920D985D8B920D8ADD8A7D8B6D8B1272C0A2020202020206C6174653A2027D984D98520D98AD8B1D8AF20D8ADD8A7D8B6D8B120D8AED984D8A7D984207B737D20D8ABD8A7D986D98AD8A92E';
wwv_flow_api.g_varchar2_table(5) := '20D8AAD8A3D983D8AF20D8A3D98620D8ADD8A7D8B6D8B120D98AD8B9D985D98420D988D8A3D98620C2ABD8B7D984D8A8D8A7D8AA20D8B5D981D8ADD8A7D8AA20D8A3D8A8D983D8B3C2BB20D985D981D8B9D991D984D8A920D981D98A20D8B5D981D8ADD8';
wwv_flow_api.g_varchar2_table(6) := 'A920D8A7D984D8B1D8A8D8B720D985D8B920D8A3D988D8B1D8A7D983D9842E272C0A2020202020207175657565643A2027D8A3D98FD8B1D8B3D98420D8A7D984D8B7D984D8A820D8A5D984D98920D8ADD8A7D8B6D8B127207D2C0A20202020656E3A207B';
wwv_flow_api.g_varchar2_table(7) := '20627573793A202753796E63696E672077697468204861646572E280A6272C20646F6E653A202753796E6365642077697468204861646572272C206661696C65643A2027486164657220636F756C64206E6F742073796E63272C0A2020202020206C6174';
wwv_flow_api.g_varchar2_table(8) := '653A2027486164657220646964206E6F7420616E737765722077697468696E207B737D207365636F6E64732E20436865636B20746861742048616465722069732072756E6E696E6720616E6420E2809C52657175657374732066726F6D20415045582070';
wwv_flow_api.g_varchar2_table(9) := '61676573E2809D206973206F6E20696E20697473204F7261636C65206C696E6B20706167652E272C0A2020202020207175657565643A2027526571756573742073656E7420746F20486164657227207D0A20207D3B0A0A202066756E6374696F6E206C61';
wwv_flow_api.g_varchar2_table(10) := '6E6728636F646529207B0A2020202069662028636F6465203D3D3D2027415227207C7C20636F6465203D3D3D2027454E2729207B2072657475726E20636F64652E746F4C6F7765724361736528293B207D0A2020202072657475726E202F5E61722F692E';
wwv_flow_api.g_varchar2_table(11) := '7465737428646F63756D656E742E646F63756D656E74456C656D656E742E6C616E67207C7C20272729203F2027617227203A2027656E273B0A20207D0A0A202066756E6374696F6E2074656C6C286F6B2C207465787429207B0A20202020696620282161';
wwv_flow_api.g_varchar2_table(12) := '7065782E6D65737361676529207B2072657475726E3B207D0A20202020696620286F6B29207B0A202020202020617065782E6D6573736167652E73686F7750616765537563636573732874657874293B0A202020207D20656C7365207B0A202020202020';
wwv_flow_api.g_varchar2_table(13) := '617065782E6D6573736167652E636C6561724572726F727328293B0A202020202020617065782E6D6573736167652E73686F774572726F7273285B7B20747970653A20276572726F72272C206C6F636174696F6E3A202770616765272C206D6573736167';
wwv_flow_api.g_varchar2_table(14) := '653A20746578742C20756E736166653A2074727565207D5D293B0A202020207D0A20207D0A0A20202F2F2074686973203D207468652064796E616D696320616374696F6E20636F6E746578742028746869732E616374696F6E2E61747472696275746530';
wwv_flow_api.g_varchar2_table(15) := '31202E2E2030352C20746869732E726573756D6543616C6C6261636B290A202066756E6374696F6E2072756E2829207B0A20202020766172206461203D20746869732C2061203D2064612E616374696F6E2C204C203D205458545B6C616E6728612E6174';
wwv_flow_api.g_varchar2_table(16) := '747269627574653034295D3B0A20202020766172206974656D73203D20612E61747472696275746530312C206C696D6974203D204D6174682E6D617828352C207061727365496E7428612E61747472696275746530322C20313029207C7C203930292C20';
wwv_flow_api.g_varchar2_table(17) := '73686F77203D20612E617474726962757465303320213D3D20274E273B0A202020207661722077616974203D202121612E77616974466F72526573756C742C20627574746F6E203D2064612E74726967676572696E67456C656D656E743B0A2020202076';
wwv_flow_api.g_varchar2_table(18) := '6172207370696E6E6572203D20617065782E7574696C20262620617065782E7574696C2E73686F775370696E6E6572203F20617065782E7574696C2E73686F775370696E6E65722829203A206E756C6C3B0A2020202069662028627574746F6E20262620';
wwv_flow_api.g_varchar2_table(19) := '627574746F6E2E7461674E616D65203D3D3D2027425554544F4E2729207B20627574746F6E2E64697361626C6564203D20747275653B207D0A202020207661722073746172746564203D20446174652E6E6F7728293B0A0A2020202066756E6374696F6E';
wwv_flow_api.g_varchar2_table(20) := '2066696E697368286F6B2C20746578742C206461746129207B0A202020202020696620287370696E6E657229207B207370696E6E65722E72656D6F766528293B207D0A20202020202069662028627574746F6E20262620627574746F6E2E7461674E616D';
wwv_flow_api.g_varchar2_table(21) := '65203D3D3D2027425554544F4E2729207B20627574746F6E2E64697361626C6564203D2066616C73653B207D0A2020202020206966202873686F77202626207465787429207B2074656C6C286F6B2C2074657874293B207D0A202020202020617065782E';
wwv_flow_api.g_varchar2_table(22) := '6576656E742E7472696767657228646F63756D656E742C206F6B203F2027686164657273796E63646F6E6527203A2027686164657273796E636661696C6564272C2064617461207C7C207B7D293B0A202020202020696620287761697429207B20617065';
wwv_flow_api.g_varchar2_table(23) := '782E64612E726573756D652864612E726573756D6543616C6C6261636B2C20216F6B293B207D0A202020207D0A0A2020202066756E6374696F6E2063616C6C28646174612C20646F6E6529207B0A202020202020766172206F707473203D207B20646174';
wwv_flow_api.g_varchar2_table(24) := '61547970653A20276A736F6E272C20737563636573733A2066756E6374696F6E20286429207B0A2020202020202020696620286420262620642E6661696C75726529207B2066696E6973682866616C73652C204C2E6661696C6564202B20273A2027202B';
wwv_flow_api.g_varchar2_table(25) := '20642E6661696C7572652C2064293B2072657475726E3B207D0A2020202020202020646F6E652864207C7C207B7D293B0A2020202020207D2C206572726F723A2066756E6374696F6E2028782C20732C206529207B2066696E6973682866616C73652C20';
wwv_flow_api.g_varchar2_table(26) := '4C2E6661696C6564202B202865203F20273A2027202B2065203A202727292C207B7D293B207D207D3B0A202020202020696620286974656D7329207B20646174612E706167654974656D73203D206974656D732E73706C697428272C27292E6D61702866';
wwv_flow_api.g_varchar2_table(27) := '756E6374696F6E20287829207B2072657475726E20272327202B20782E7472696D28293B207D292E6A6F696E28272C27293B207D0A202020202020617065782E7365727665722E706C7567696E28612E616A61784964656E7469666965722C2064617461';
wwv_flow_api.g_varchar2_table(28) := '2C206F707473293B0A202020207D0A0A2020202063616C6C287B207830313A202741534B27207D2C2066756E6374696F6E20287229207B0A2020202020206966202821722E696429207B2066696E6973682866616C73652C204C2E6661696C65642C2072';
wwv_flow_api.g_varchar2_table(29) := '293B2072657475726E3B207D0A202020202020696620282177616974202626202173686F7729207B2066696E69736828747275652C2027272C2072293B2072657475726E3B207D0A2020202020202866756E6374696F6E20706F6C6C2829207B0A202020';
wwv_flow_api.g_varchar2_table(30) := '202020202069662028446174652E6E6F772829202D2073746172746564203E206C696D6974202A203130303029207B0A2020202020202020202066696E6973682866616C73652C204C2E6C6174652E7265706C61636528277B737D272C206C696D697429';
wwv_flow_api.g_varchar2_table(31) := '2C207B2069643A20722E69642C207374617475733A20274E455727207D293B0A2020202020202020202072657475726E3B0A20202020202020207D0A202020202020202073657454696D656F75742866756E6374696F6E202829207B0A20202020202020';
wwv_flow_api.g_varchar2_table(32) := '20202063616C6C287B207830313A2027535441545553272C207830323A20722E6964207D2C2066756E6374696F6E20287329207B0A20202020202020202020202069662028732E737461747573203D3D3D2027444F4E452729207B2066696E6973682874';
wwv_flow_api.g_varchar2_table(33) := '7275652C204C2E646F6E652C2073293B207D2020202F2F207468652064657461696C732074726176656C20776974682074686520686164657273796E63646F6E65206576656E740A202020202020202020202020656C73652069662028732E7374617475';
wwv_flow_api.g_varchar2_table(34) := '73203D3D3D20274641494C45442729207B2066696E6973682866616C73652C204C2E6661696C6564202B2028732E6D657373616765203F20273A2027202B20732E6D657373616765203A202727292C2073293B207D0A202020202020202020202020656C';
wwv_flow_api.g_varchar2_table(35) := '7365207B20706F6C6C28293B207D0A202020202020202020207D293B0A20202020202020207D2C2031353030293B0A2020202020207D2829293B0A202020207D293B0A20207D0A202072657475726E207B2072756E3A2072756E207D3B0A7D2829293B0A';
end;
/
prompt --application/shared_components/plugins/dynamic_action/com_hader_sync/hader-sync.js
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(91734400000018)
,p_plugin_id=>wwv_flow_api.id(91734400000001)
,p_file_name=>'hader-sync.js'
,p_mime_type=>'application/javascript'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_api.varchar2_to_blob(wwv_flow_api.g_varchar2_table)
);
end;
/
prompt --application/end_environment
begin
wwv_flow_api.import_end(p_auto_install_sup_obj => nvl(wwv_flow_application_install.get_auto_install_sup_obj, false));
commit;
end;
/
set verify on feedback on define on
prompt  ...done
