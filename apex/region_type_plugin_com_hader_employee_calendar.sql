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
--     PLUGIN: COM.HADER.EMPLOYEE_CALENDAR
--   Manifest End
--   Version:         19.2.0.00.18
--   Instance ID:     1
--

prompt --application/shared_components/plugins/region_type/com_hader_employee_calendar
begin
wwv_flow_api.create_plugin(
 p_id=>wwv_flow_api.id(91734300000001)
,p_plugin_type=>'REGION TYPE'
,p_name=>'COM.HADER.EMPLOYEE_CALENDAR'
,p_display_name=>'Hader Employee Calendar (حاضر - تقويم حضور الموظف)'
,p_supported_ui_types=>'DESKTOP:JQM_SMARTPHONE'
,p_javascript_file_urls=>'#PLUGIN_FILES#hader-calendar.js'
,p_css_file_urls=>'#PLUGIN_FILES#hader-calendar.css'
,p_plsql_code=>wwv_flow_string.join(wwv_flow_t_varchar2(
'-- Hader employee attendance calendar (region plug-in). APEX 19.2 and later, Oracle 11g and later.',
'-- Reads HADER_V_ATT_REPORT, HADER_V_PEOPLE (and HADER_EMP_PHOTOS when present).',
'',
'function obj (p_region in apex_plugin.t_region, p_name in varchar2) return varchar2 is',
'  l_owner varchar2(200) := trim(p_region.attribute_01);',
'begin',
'  if l_owner is null then',
'    return p_name;',
'  end if;',
'  if not regexp_like(l_owner, ''^[A-Za-z][A-Za-z0-9_$#]{0,29}(@[A-Za-z][A-Za-z0-9_$#.]{0,120})?$'') then',
'    raise_application_error(-20001, ''Hader calendar: invalid owner '' || l_owner);',
'  end if;',
'  if instr(l_owner, ''@'') > 0 then   -- OWNER@DBLINK',
'    return substr(l_owner, 1, instr(l_owner, ''@'') - 1) || ''.'' || p_name || substr(l_owner, instr(l_owner, ''@''));',
'  end if;',
'  return l_owner || ''.'' || p_name;',
'end obj;',
'',
'-- The employee shown. USER_CODE / USER_EMAIL lock the calendar to the signed-in user (self-service pages):',
'-- nothing sent by the browser can show somebody else.',
'function employee (p_region in apex_plugin.t_region) return varchar2 is',
'  l_code varchar2(100);',
'begin',
'  case nvl(p_region.attribute_02, ''ITEM'')',
'    when ''USER_CODE'' then',
'      l_code := v(''APP_USER'');',
'    when ''USER_EMAIL'' then',
'      begin',
'        execute immediate ''select emp_code from '' || obj(p_region, ''HADER_V_PEOPLE'') ||',
'                          '' where upper(email) = upper(:u) and rownum = 1'' into l_code using v(''APP_USER'');',
'      exception when no_data_found then',
'        l_code := null;',
'      end;',
'    else',
'      if p_region.attribute_03 is not null then',
'        l_code := v(p_region.attribute_03);',
'      end if;',
'  end case;',
'  return trim(l_code);',
'end employee;',
'',
'-- whether the signed-in user may see this employee: the page item may have been changed in the browser, so in',
'-- Hader for Oracle APEX whoever does not see the attendance (HDR_UI.may attendance.view) sees only themself',
'-- (HDR_UI.me_code); with the Hader program alone (no HDR_UI here) the application''s own authorization decides',
'function may_see (p_region in apex_plugin.t_region, p_emp in varchar2) return boolean is',
'  l_may varchar2(1);',
'  l_me  varchar2(100);',
'begin',
'  if nvl(p_region.attribute_02, ''ITEM'') <> ''ITEM'' then',
'    return true;          -- USER_CODE / USER_EMAIL: the signed-in user''s own',
'  end if;',
'  execute immediate ''begin :m := '' || obj(p_region, ''HDR_UI'') || ''.may(:u, ''''attendance.view''''); :e := ''',
'    || obj(p_region, ''HDR_UI'') || ''.me_code(:u); end;'' using out l_may, in v(''APP_USER''), out l_me;',
'  return l_may = ''Y'' or l_me = p_emp;',
'exception when others then',
'  return sqlcode in (-6550, -942, -4043, -201);',
'end may_see;',
'',
'function render (',
'  p_region              in apex_plugin.t_region,',
'  p_plugin              in apex_plugin.t_plugin,',
'  p_is_printer_friendly in boolean )',
'  return apex_plugin.t_region_render_result',
'is',
'  -- the region itself already carries the static id (or R<id>): the calendar gets its own',
'  l_id    varchar2(255) := nvl(p_region.static_id, ''R'' || p_region.id) || ''_hcal'';',
'  l_items varchar2(4000);',
'begin',
'  if nvl(p_region.attribute_02, ''ITEM'') = ''ITEM'' and p_region.attribute_03 is not null then',
'    l_items := p_region.attribute_03;',
'  end if;',
'  if p_region.attribute_04 is not null then',
'    l_items := l_items || case when l_items is not null then '','' end || p_region.attribute_04;',
'  end if;',
'  if p_region.ajax_items_to_submit is not null then   -- the items the region''s own query (Source) uses',
'    l_items := l_items || case when l_items is not null then '','' end || p_region.ajax_items_to_submit;',
'  end if;',
'  sys.htp.p(''<div id="'' || apex_escape.html_attribute(l_id) || ''" class="hdr-c"><div class="hdr-c-load"></div></div>'');',
'  apex_javascript.add_onload_code(',
'    ''hdrCal.init('' ||',
'    apex_javascript.add_value(l_id) ||',
'    apex_javascript.add_value(apex_plugin.get_ajax_identifier) ||',
'    apex_javascript.add_value(l_items) ||',
'    apex_javascript.add_value(p_region.attribute_04) ||',
'    apex_javascript.add_value(nvl(p_region.attribute_05, ''AUTO'')) ||',
'    apex_javascript.add_value(nvl(p_region.attribute_06, ''SAT'')) ||',
'    apex_javascript.add_value(nvl(p_region.attribute_07, ''Y''), false) || '');'');',
'  return null;',
'end render;',
'',
'function ajax (',
'  p_region in apex_plugin.t_region,',
'  p_plugin in apex_plugin.t_plugin )',
'  return apex_plugin.t_region_ajax_result',
'is',
'  l_emp    varchar2(100) := employee(p_region);',
'  l_month  date;',
'  l_cur    sys_refcursor;',
'  l_blob   blob;',
'  l_photo  number := 0;',
'  l_name   varchar2(400); l_name_en varchar2(400); l_dept varchar2(400);',
'  l_d date; l_st varchar2(30); l_ar varchar2(100); l_en varchar2(100); l_tt varchar2(100);',
'  l_si date; l_so date; l_ci date; l_co date;',
'  l_req number; l_wk number; l_late number; l_early number; l_ot number; l_lv number; l_ab number;',
'  l_lc varchar2(200); l_hol varchar2(200); l_pn varchar2(1000);',
'  l_x number; l_p number; l_l number; l_a number; l_v number;',
'  l_ctx    apex_exec.t_context;',
'  l_params apex_exec.t_parameters;',
'  function hm (p date) return varchar2 is begin return to_char(p, ''HH24:MI''); end;',
'begin',
'  if l_emp is not null and not may_see(p_region, l_emp) then',
'    sys.owa_util.status_line(403, ''Forbidden'', true);',
'    return null;',
'  end if;',
'  -- the employee''s photo (only the employee this region shows)',
'  if apex_application.g_x01 = ''PHOTO'' then',
'    begin',
'      execute immediate ''select photo from '' || obj(p_region, ''HADER_EMP_PHOTOS'') || '' where emp_code = :c''',
'        into l_blob using l_emp;',
'      sys.owa_util.mime_header(''image/jpeg'', false);',
'      sys.htp.p(''Content-Length: '' || dbms_lob.getlength(l_blob));',
'      sys.htp.p(''Cache-Control: private, max-age=3600'');',
'      sys.owa_util.http_header_close;',
'      sys.wpg_docload.download_file(l_blob);',
'    exception when others then',
'      sys.owa_util.status_line(404, ''Not Found'', true);',
'    end;',
'    return null;',
'  end if;',
'',
'  -- month: from the calendar''s own navigation, else the month item, else this month',
'  begin',
'    l_month := to_date(substr(nvl(apex_application.g_x01,',
'                 case when p_region.attribute_04 is not null then v(p_region.attribute_04) end), 1, 7), ''YYYY-MM'');',
'  exception when others then',
'    l_month := null;',
'  end;',
'  l_month := trunc(nvl(l_month, sysdate), ''MM'');',
'',
'  apex_json.open_object;',
'  apex_json.write(''month'', to_char(l_month, ''YYYY-MM''));',
'  apex_json.write(''today'', to_char(sysdate, ''YYYY-MM-DD''));',
'  if l_emp is null then',
'    apex_json.write(''empty'', true);',
'    apex_json.close_object;',
'    return null;',
'  end if;',
'',
'  begin',
'    execute immediate ''select full_name, name_en, dept_name from '' || obj(p_region, ''HADER_V_PEOPLE'') ||',
'      '' where emp_code = :c and rownum = 1''',
'      into l_name, l_name_en, l_dept using l_emp;',
'  exception when no_data_found then',
'    null;',
'  end;',
'  if nvl(p_region.attribute_07, ''Y'') = ''Y'' then',
'    begin',
'      execute immediate ''select count(*) from '' || obj(p_region, ''HADER_EMP_PHOTOS'') || '' where emp_code = :c''',
'        into l_photo using l_emp;',
'    exception when others then   -- no photos table: initials instead',
'      l_photo := 0;',
'    end;',
'  end if;',
'  apex_json.open_object(''emp'');',
'  apex_json.write(''code'', l_emp);',
'  apex_json.write(''name'', l_name);',
'  apex_json.write(''name_en'', l_name_en);',
'  apex_json.write(''dept'', l_dept);',
'  apex_json.write(''photo'', l_photo > 0);',
'  apex_json.close_object;',
'',
'  apex_json.open_array(''days'');',
'  -- the days: from the region''s own query (Source, in Page Designer) when it has one, with the columns of',
'  -- HADER_V_ATT_REPORT (any table, view or query of yours with those names), else that view; always the one',
'  -- employee this region shows and the month',
'  apex_exec.add_parameter(l_params, ''HDR_EMP'', l_emp);',
'  apex_exec.add_parameter(l_params, ''HDR_MONTH'', l_month);',
'  l_ctx := apex_exec.open_query_context(',
'             p_location       => apex_exec.c_location_local_db,',
'             p_sql_query      =>',
'               ''select att_date, status, status_ar, status_en, timetable, sched_in, sched_out, clock_in, clock_out,',
'                       required_min, worked_min, late_min, early_min, ot_min, leave_min, absent_days, leave_codes, holiday,',
'                       punches, is_expected, is_present, is_late, is_absent, is_leave',
'                  from ('' || nvl(trim(p_region.source), ''select * from '' || obj(p_region, ''HADER_V_ATT_REPORT'')) || '')',
'                 where emp_code = :HDR_EMP and att_date >= :HDR_MONTH and att_date < add_months(:HDR_MONTH, 1)',
'                 order by att_date'',',
'             p_sql_parameters => l_params);',
'  while apex_exec.next_row(l_ctx) loop',
'    l_d := apex_exec.get_date(l_ctx, 1);',
'    l_st := apex_exec.get_varchar2(l_ctx, 2);',
'    l_ar := apex_exec.get_varchar2(l_ctx, 3);',
'    l_en := apex_exec.get_varchar2(l_ctx, 4);',
'    l_tt := apex_exec.get_varchar2(l_ctx, 5);',
'    l_si := apex_exec.get_date(l_ctx, 6);',
'    l_so := apex_exec.get_date(l_ctx, 7);',
'    l_ci := apex_exec.get_date(l_ctx, 8);',
'    l_co := apex_exec.get_date(l_ctx, 9);',
'    l_req := apex_exec.get_number(l_ctx, 10);',
'    l_wk := apex_exec.get_number(l_ctx, 11);',
'    l_late := apex_exec.get_number(l_ctx, 12);',
'    l_early := apex_exec.get_number(l_ctx, 13);',
'    l_ot := apex_exec.get_number(l_ctx, 14);',
'    l_lv := apex_exec.get_number(l_ctx, 15);',
'    l_ab := apex_exec.get_number(l_ctx, 16);',
'    l_lc := apex_exec.get_varchar2(l_ctx, 17);',
'    l_hol := apex_exec.get_varchar2(l_ctx, 18);',
'    l_pn := apex_exec.get_varchar2(l_ctx, 19);',
'    l_x := apex_exec.get_number(l_ctx, 20);',
'    l_p := apex_exec.get_number(l_ctx, 21);',
'    l_l := apex_exec.get_number(l_ctx, 22);',
'    l_a := apex_exec.get_number(l_ctx, 23);',
'    l_v := apex_exec.get_number(l_ctx, 24);',
'    apex_json.open_object;',
'    apex_json.write(''d'', to_char(l_d, ''YYYY-MM-DD''));',
'    apex_json.write(''st'', l_st);',
'    apex_json.write(''ar'', l_ar);',
'    apex_json.write(''en'', l_en);',
'    apex_json.write(''tt'', l_tt);',
'    apex_json.write(''si'', hm(l_si));',
'    apex_json.write(''so'', hm(l_so));',
'    apex_json.write(''ci'', hm(l_ci));',
'    apex_json.write(''co'', hm(l_co));',
'    apex_json.write(''req'', l_req);',
'    apex_json.write(''wk'', l_wk);',
'    apex_json.write(''late'', l_late);',
'    apex_json.write(''early'', l_early);',
'    apex_json.write(''ot'', l_ot);',
'    apex_json.write(''lv'', l_lv);',
'    apex_json.write(''ab'', l_ab);',
'    apex_json.write(''lc'', l_lc);',
'    apex_json.write(''hol'', l_hol);',
'    apex_json.write(''pn'', l_pn);',
'    apex_json.write(''x'', l_x);',
'    apex_json.write(''p'', l_p);',
'    apex_json.write(''l'', l_l);',
'    apex_json.write(''a'', l_a);',
'    apex_json.write(''v'', l_v);',
'    apex_json.close_object;',
'  end loop;',
'  apex_exec.close(l_ctx);',
'  apex_json.close_array;',
'  apex_json.close_object;',
'  return null;',
'exception when others then',
'  if l_cur%isopen then',
'    close l_cur;',
'  end if;',
'  apex_exec.close(l_ctx);',
'  apex_json.free_output;',
'  sys.htp.init;   -- drop the half-written JSON',
'  apex_json.open_object;',
'  apex_debug.error(''Hader calendar: %s'', sqlerrm);',
'  -- the database''s own words to a developer (debug, or signed in to App Builder); to anybody else not',
'  apex_json.write(''failure'', case when apex_application.g_debug or v(''APP_BUILDER_SESSION'') is not null',
'    then sqlerrm ||',
'    case when sqlcode = -904 then '' — HADER_V_ATT_REPORT is older than this plug-in: press "Create the link objects" in Hader'' end',
'    else ''The region could not be read (run the page with debug for the detail)'' end);   -- not ''error''',
'  apex_json.close_object;',
'  return null;',
'end ajax;'))
,p_api_version=>1
,p_render_function=>'render'
,p_ajax_function=>'ajax'
,p_standard_attributes=>'SOURCE_SQL:AJAX_ITEMS_TO_SUBMIT'
,p_sql_min_column_count=>1
,p_substitute_attributes=>true
,p_subscribe_plugin_settings=>true
,p_help_text=>'One employee''s month from Hader: status of every day, in and out, hours worked against required, late, absence, leave and overtime, with the day''s punches on a click. For HR pages (employee chosen in an item) and for self-service pages (locked to the signed-in user). Source (optional): a query of yours in place of HADER_V_ATT_REPORT with its column names (EMP_CODE, ATT_DATE, STATUS, STATUS_AR, STATUS_EN, TIMETABLE, SCHED_IN, SCHED_OUT, CLOCK_IN, CLOCK_OUT, REQUIRED_MIN, WORKED_MIN, LATE_MIN, EARLY_MIN, OT_MIN, LEAVE_MIN, ABSENT_DAYS, LEAVE_CODES, HOLIDAY, PUNCHES, IS_EXPECTED, IS_PRESENT, IS_LATE, IS_ABSENT, IS_LEAVE); the calendar keeps to its one employee and month whatever the query.'
,p_version_identifier=>'1.3'
,p_files_version=>25007
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(91734300000002)
,p_plugin_id=>wwv_flow_api.id(91734300000001)
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
 p_id=>wwv_flow_api.id(91734300000003)
,p_plugin_id=>wwv_flow_api.id(91734300000001)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>2
,p_display_sequence=>20
,p_prompt=>'Employee from'
,p_attribute_type=>'SELECT LIST'
,p_is_required=>true
,p_default_value=>'ITEM'
,p_is_translatable=>false
,p_lov_type=>'STATIC'
,p_help_text=>'Page item: the employee number (EMP_CODE) in a page item. Signed-in user: the APEX user name is the employee number, or the user name is the employee''s e-mail in HADER_V_PEOPLE — the calendar then always shows the signed-in employee and nothing sent from the browser can change that (use it for self-service pages).'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(91734300000004)
,p_plugin_attribute_id=>wwv_flow_api.id(91734300000003)
,p_display_sequence=>10
,p_display_value=>'Page item'
,p_return_value=>'ITEM'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(91734300000005)
,p_plugin_attribute_id=>wwv_flow_api.id(91734300000003)
,p_display_sequence=>20
,p_display_value=>'Signed-in user = employee number'
,p_return_value=>'USER_CODE'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(91734300000006)
,p_plugin_attribute_id=>wwv_flow_api.id(91734300000003)
,p_display_sequence=>30
,p_display_value=>'Signed-in user = employee e-mail'
,p_return_value=>'USER_EMAIL'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(91734300000007)
,p_plugin_id=>wwv_flow_api.id(91734300000001)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>3
,p_display_sequence=>30
,p_prompt=>'Employee item'
,p_attribute_type=>'PAGE ITEM'
,p_is_required=>false
,p_is_translatable=>false
,p_help_text=>'Page item holding the employee number (EMP_CODE) when "Employee from" is Page item. The calendar reloads when it changes. The browser sends it, so with Hader for Oracle APEX a user who does not see the attendance sees only themself whatever it holds; for a self-service page choose a signed-in user option instead.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(91734300000008)
,p_plugin_id=>wwv_flow_api.id(91734300000001)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>4
,p_display_sequence=>40
,p_prompt=>'Month item'
,p_attribute_type=>'PAGE ITEM'
,p_is_required=>false
,p_is_translatable=>false
,p_help_text=>'Optional page item with the month to show (YYYY-MM or a date). Empty = this month; the calendar has its own previous / next buttons.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(91734300000009)
,p_plugin_id=>wwv_flow_api.id(91734300000001)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>5
,p_display_sequence=>50
,p_prompt=>'Language'
,p_attribute_type=>'SELECT LIST'
,p_is_required=>true
,p_default_value=>'AUTO'
,p_is_translatable=>false
,p_lov_type=>'STATIC'
,p_help_text=>'Automatic follows the application language.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(91734300000010)
,p_plugin_attribute_id=>wwv_flow_api.id(91734300000009)
,p_display_sequence=>10
,p_display_value=>'Automatic'
,p_return_value=>'AUTO'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(91734300000011)
,p_plugin_attribute_id=>wwv_flow_api.id(91734300000009)
,p_display_sequence=>20
,p_display_value=>'العربية'
,p_return_value=>'AR'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(91734300000012)
,p_plugin_attribute_id=>wwv_flow_api.id(91734300000009)
,p_display_sequence=>30
,p_display_value=>'English'
,p_return_value=>'EN'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(91734300000013)
,p_plugin_id=>wwv_flow_api.id(91734300000001)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>6
,p_display_sequence=>60
,p_prompt=>'Week starts on'
,p_attribute_type=>'SELECT LIST'
,p_is_required=>true
,p_default_value=>'SAT'
,p_is_translatable=>false
,p_lov_type=>'STATIC'
,p_help_text=>'First column of the calendar.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(91734300000014)
,p_plugin_attribute_id=>wwv_flow_api.id(91734300000013)
,p_display_sequence=>10
,p_display_value=>'Saturday'
,p_return_value=>'SAT'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(91734300000015)
,p_plugin_attribute_id=>wwv_flow_api.id(91734300000013)
,p_display_sequence=>20
,p_display_value=>'Sunday'
,p_return_value=>'SUN'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(91734300000016)
,p_plugin_attribute_id=>wwv_flow_api.id(91734300000013)
,p_display_sequence=>30
,p_display_value=>'Monday'
,p_return_value=>'MON'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(91734300000017)
,p_plugin_id=>wwv_flow_api.id(91734300000001)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>7
,p_display_sequence=>70
,p_prompt=>'Show photo'
,p_attribute_type=>'CHECKBOX'
,p_is_required=>false
,p_default_value=>'Y'
,p_is_translatable=>false
,p_help_text=>'The employee''s picture from HADER_EMP_PHOTOS.'
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '2F2A20486164657220656D706C6F79656520617474656E64616E63652063616C656E64617220E28094204150455820726567696F6E20706C75672D696E2E204E6F206F74686572206C696272617269657320287573657320617065782E73657276657229';
wwv_flow_api.g_varchar2_table(2) := '2E202A2F0A77696E646F772E68647243616C203D2077696E646F772E68647243616C207C7C202866756E6374696F6E202829207B0A20202775736520737472696374273B0A202076617220545854203D207B0A2020202061723A207B206D6F6E7468733A';
wwv_flow_api.g_varchar2_table(3) := '205B27D98AD986D8A7D98AD8B1272C2027D981D8A8D8B1D8A7D98AD8B1272C2027D985D8A7D8B1D8B3272C2027D8A3D8A8D8B1D98AD984272C2027D985D8A7D98AD988272C2027D98AD988D986D98AD988272C2027D98AD988D984D98AD988272C2027D8';
wwv_flow_api.g_varchar2_table(4) := 'A3D8BAD8B3D8B7D8B3272C2027D8B3D8A8D8AAD985D8A8D8B1272C2027D8A3D983D8AAD988D8A8D8B1272C2027D986D988D981D985D8A8D8B1272C2027D8AFD98AD8B3D985D8A8D8B1275D2C0A202020202020646179733A205B27D8A3D8ADD8AF272C20';
wwv_flow_api.g_varchar2_table(5) := '27D8A5D8ABD986D98AD986272C2027D8ABD984D8A7D8ABD8A7D8A1272C2027D8A3D8B1D8A8D8B9D8A7D8A1272C2027D8AED985D98AD8B3272C2027D8ACD985D8B9D8A9272C2027D8B3D8A8D8AA275D2C0A202020202020707265763A2027D8A7D984D8B4';
wwv_flow_api.g_varchar2_table(6) := 'D987D8B120D8A7D984D8B3D8A7D8A8D982272C206E6578743A2027D8A7D984D8B4D987D8B120D8A7D984D8AAD8A7D984D98A272C20746F6461793A2027D8A7D984D98AD988D985272C20776F726B65643A2027D8B3D8A7D8B9D8A7D8AA20D8A7D984D8B9';
wwv_flow_api.g_varchar2_table(7) := 'D985D984272C206F663A2027D985D986272C2070726573656E743A2027D8A3D98AD8A7D98520D8A7D984D8ADD8B6D988D8B1272C0A2020202020206C6174653A2027D985D8B1D8A7D8AA20D8A7D984D8AAD8A3D8AED98AD8B1272C206D696E3A2027D8AF';
wwv_flow_api.g_varchar2_table(8) := '272C20616273656E743A2027D8BAD98AD8A7D8A8272C206C656176653A2027D8A5D8ACD8A7D8B2D8A9272C206F743A2027D8A5D8B6D8A7D981D98A272C206D697373696E673A2027D8A8D8B5D985D8A920D986D8A7D982D8B5D8A9272C20683A2027D8B3';
wwv_flow_api.g_varchar2_table(9) := '272C0A2020202020207069636B3A2027D8A7D8AED8AAD8B120D985D988D8B8D981D8A7D98B20D984D8B9D8B1D8B620D8ADD8B6D988D8B1D987272C206E6F6E653A2027D984D8A720D8AAD988D8ACD8AF20D8A8D98AD8A7D986D8A7D8AA20D984D987D8B0';
wwv_flow_api.g_varchar2_table(10) := 'D8A720D8A7D984D8B4D987D8B1272C206572726F723A2027D8AAD8B9D8B0D991D8B120D8AAD8ADD985D98AD98420D8A7D984D8AAD982D988D98AD985272C0A20202020202073686966743A2027D8A7D984D8AFD988D8A7D985272C20696E6F75743A2027';
wwv_flow_api.g_varchar2_table(11) := 'D8A7D984D8AFD8AED988D98420D988D8A7D984D8AED8B1D988D8AC272C2070756E636865733A2027D8A7D984D8A8D8B5D985D8A7D8AA272C206C6174654D696E3A2027D8AAD8A3D8AED98AD8B1272C206561726C794D696E3A2027D8AED8B1D988D8AC20';
wwv_flow_api.g_varchar2_table(12) := 'D985D8A8D983D8B1272C206F744D696E3A2027D8A5D8B6D8A7D981D98A272C0A2020202020206C656176654D696E3A2027D8A5D8ACD8A7D8B2D8A9272C20686F6C696461793A2027D8B9D8B7D984D8A9272C20636C6F73653A2027D8A5D8BAD984D8A7D9';
wwv_flow_api.g_varchar2_table(13) := '8227207D2C0A20202020656E3A207B206D6F6E7468733A205B274A616E75617279272C20274665627275617279272C20274D61726368272C2027417072696C272C20274D6179272C20274A756E65272C20274A756C79272C2027417567757374272C2027';
wwv_flow_api.g_varchar2_table(14) := '53657074656D626572272C20274F63746F626572272C20274E6F76656D626572272C2027446563656D626572275D2C0A202020202020646179733A205B2753756E272C20274D6F6E272C2027547565272C2027576564272C2027546875272C2027467269';
wwv_flow_api.g_varchar2_table(15) := '272C2027536174275D2C0A202020202020707265763A202750726576696F7573206D6F6E7468272C206E6578743A20274E657874206D6F6E7468272C20746F6461793A2027546F646179272C20776F726B65643A2027486F75727320776F726B6564272C';
wwv_flow_api.g_varchar2_table(16) := '206F663A20276F66272C2070726573656E743A2027446179732070726573656E74272C0A2020202020206C6174653A20274C617465206172726976616C73272C206D696E3A20276D272C20616273656E743A2027416273656E74272C206C656176653A20';
wwv_flow_api.g_varchar2_table(17) := '274C65617665272C206F743A20274F76657274696D65272C206D697373696E673A20274D69737365642070756E6368272C20683A202768272C0A2020202020207069636B3A202743686F6F736520616E20656D706C6F79656520746F2073656520746865';
wwv_flow_api.g_varchar2_table(18) := '20617474656E64616E6365272C206E6F6E653A20274E6F206461746120666F722074686973206D6F6E7468272C206572726F723A2027436F756C64206E6F74206C6F6164207468652063616C656E646172272C0A20202020202073686966743A20275368';
wwv_flow_api.g_varchar2_table(19) := '696674272C20696E6F75743A2027496E20616E64206F7574272C2070756E636865733A202750756E63686573272C206C6174654D696E3A20274C617465272C206561726C794D696E3A20274561726C79206C65617665272C206F744D696E3A20274F7665';
wwv_flow_api.g_varchar2_table(20) := '7274696D65272C0A2020202020206C656176654D696E3A20274C65617665272C20686F6C696461793A2027486F6C69646179272C20636C6F73653A2027436C6F736527207D0A20207D3B0A202076617220434F4C4F5253203D207B2070726573656E743A';
wwv_flow_api.g_varchar2_table(21) := '202723306361333063272C206C6174653A202723653861313062272C206561726C793A202723643937373036272C206C6174655F6561726C793A202723656135383063272C20616273656E743A202723643033623362272C0A202020207061727469616C';
wwv_flow_api.g_varchar2_table(22) := '5F616273656E743A202723653036303761272C206C656176653A202723346133616137272C20686F6C696461793A202723326137386436272C206F66663A202723396161336165272C20696E636F6D706C6574653A202723633032366433272C0A202020';
wwv_flow_api.g_varchar2_table(23) := '20756E7363686564756C65643A202723623863306361272C2070656E64696E673A20272339346133623827207D3B0A2020766172205354415254203D207B2053554E3A20302C204D4F4E3A20312C205341543A2036207D3B0A0A202066756E6374696F6E';
wwv_flow_api.g_varchar2_table(24) := '20657363287629207B0A2020202072657475726E20537472696E672876203D3D206E756C6C203F202727203A2076292E7265706C616365282F5B263C3E22275D2F672C2066756E6374696F6E20286329207B0A20202020202072657475726E207B202726';
wwv_flow_api.g_varchar2_table(25) := '273A202726616D703B272C20273C273A2027266C743B272C20273E273A20272667743B272C202722273A20272671756F743B272C202227223A2027262333393B27207D5B635D3B0A202020207D293B0A20207D0A20202F2F20746865207374616E642D69';
wwv_flow_api.g_varchar2_table(26) := '6E20666F722061206D697373696E6720706963747572653A20746865206E616D652773206669727374206C65747465722C206F72206120706572736F6E20286E657665722061206469676974206F6620746865206E756D626572290A202066756E637469';
wwv_flow_api.g_varchar2_table(27) := '6F6E20696E697469616C286E616D6529207B0A202020207661722063203D20537472696E67286E616D65207C7C202727292E7472696D28292E7265706C616365282F5E5B5C645C732E5C2D5F2F28295D2B2F2C202727292E6368617241742830293B0A20';
wwv_flow_api.g_varchar2_table(28) := '20202072657475726E2063203F20657363286329203A20273C7376672076696577426F783D22302030203234203234222066696C6C3D2263757272656E74436F6C6F722220617269612D68696464656E3D227472756522207374796C653D227769647468';
wwv_flow_api.g_varchar2_table(29) := '3A3630253B6865696768743A363025223E3C7061746820643D224D313220313261342E3520342E352030203130302D3920342E3520342E3520302030303020397A6D302032632D3420302D3820322D3820357632683136762D3263302D332D342D352D38';
wwv_flow_api.g_varchar2_table(30) := '2D357A222F3E3C2F7376673E273B0A20207D0A202066756E6374696F6E20686F757273286D696E29207B20766172206D203D204D6174682E726F756E64286D696E207C7C2030293B2072657475726E204D6174682E666C6F6F72286D202F20363029202B';
wwv_flow_api.g_varchar2_table(31) := '20273A27202B2028273027202B20286D202520363029292E736C696365282D32293B207D0A202066756E6374696F6E20796D6428792C206D2C206429207B2072657475726E2079202B20272D27202B2028273027202B206D292E736C696365282D322920';
wwv_flow_api.g_varchar2_table(32) := '2B20272D27202B2028273027202B2064292E736C696365282D32293B207D0A202066756E6374696F6E206164644D6F6E746828796D2C206E29207B0A202020207661722079203D202B796D2E736C69636528302C2034292C206D203D202B796D2E736C69';
wwv_flow_api.g_varchar2_table(33) := '636528352C203729202D2031202B206E3B0A2020202079202B3D204D6174682E666C6F6F72286D202F203132293B206D203D2028286D202520313229202B2031322920252031323B0A2020202072657475726E2079202B20272D27202B2028273027202B';
wwv_flow_api.g_varchar2_table(34) := '20286D202B203129292E736C696365282D32293B0A20207D0A0A202066756E6374696F6E2073756D6D617279284C2C206461797329207B0A202020207661722074203D207B20776B3A20302C207265713A20302C20783A20302C20703A20302C206C3A20';
wwv_flow_api.g_varchar2_table(35) := '302C206C6D3A20302C20613A20302C20763A20302C206F743A20302C206D6973733A2030207D3B0A20202020646179732E666F72456163682866756E6374696F6E20286429207B0A202020202020742E776B202B3D20642E776B207C7C20303B20742E72';
wwv_flow_api.g_varchar2_table(36) := '6571202B3D20642E726571207C7C20303B20742E78202B3D20642E78207C7C20303B20742E70202B3D20642E70207C7C20303B20742E6C202B3D20642E6C207C7C20303B0A202020202020742E6C6D202B3D20642E6C617465207C7C20303B20742E6120';
wwv_flow_api.g_varchar2_table(37) := '2B3D20642E6162207C7C20303B20742E76202B3D20642E76207C7C20303B20742E6F74202B3D20642E6F74207C7C20303B20742E6D697373202B3D20642E7374203D3D3D2027696E636F6D706C65746527203F2031203A20303B0A202020207D293B0A20';
wwv_flow_api.g_varchar2_table(38) := '202020766172206368697073203D205B0A2020202020205B4C2E776F726B65642C20686F75727328742E776B29202B2027203C736D616C6C3E27202B20657363284C2E6F6629202B20272027202B20686F75727328742E72657129202B20273C2F736D61';
wwv_flow_api.g_varchar2_table(39) := '6C6C3E272C202723306538663836275D2C0A2020202020205B4C2E70726573656E742C20742E70202B2027203C736D616C6C3E27202B20657363284C2E6F6629202B20272027202B20742E78202B20273C2F736D616C6C3E272C20434F4C4F52532E7072';
wwv_flow_api.g_varchar2_table(40) := '6573656E745D2C0A2020202020205B4C2E6C6174652C20742E6C202B2028742E6C6D203F2027203C736D616C6C3E27202B204D6174682E726F756E6428742E6C6D29202B20272027202B20657363284C2E6D696E29202B20273C2F736D616C6C3E27203A';
wwv_flow_api.g_varchar2_table(41) := '202727292C20434F4C4F52532E6C6174655D2C0A2020202020205B4C2E616273656E742C20537472696E67284D6174682E726F756E6428742E61202A2031303029202F20313030292C20434F4C4F52532E616273656E745D2C0A2020202020205B4C2E6C';
wwv_flow_api.g_varchar2_table(42) := '656176652C20537472696E6728742E76292C20434F4C4F52532E6C656176655D2C0A2020202020205B4C2E6F742C20686F75727328742E6F74292C202723326137386436275D0A202020205D3B0A2020202069662028742E6D69737329207B2063686970';
wwv_flow_api.g_varchar2_table(43) := '732E70757368285B4C2E6D697373696E672C20537472696E6728742E6D697373292C20434F4C4F52532E696E636F6D706C6574655D293B207D0A2020202072657475726E20273C64697620636C6173733D226864722D632D73756D223E27202B20636869';
wwv_flow_api.g_varchar2_table(44) := '70732E6D61702866756E6374696F6E20286329207B0A20202020202072657475726E20273C64697620636C6173733D226864722D632D63686970223E3C69207374796C653D226261636B67726F756E643A27202B20635B325D202B2027223E3C2F693E3C';
wwv_flow_api.g_varchar2_table(45) := '623E27202B20635B315D202B20273C2F623E3C7370616E3E27202B2065736328635B305D29202B20273C2F7370616E3E3C2F6469763E273B0A202020207D292E6A6F696E28272729202B20273C2F6469763E273B0A20207D0A0A202066756E6374696F6E';
wwv_flow_api.g_varchar2_table(46) := '2064657461696C284C2C206C616E672C206429207B0A2020202076617220726F7773203D205B5D3B0A20202020766172206E616D65203D206C616E67203D3D3D2027617227203F2028642E6172207C7C20642E737429203A2028642E656E207C7C20642E';
wwv_flow_api.g_varchar2_table(47) := '7374293B0A202020202F2F205C75323036362E2E5C7532303639206B65657020612074696D652072616E676520696E206F72646572206E65787420746F204172616269632074657874202864696769747320616674657220417261626963206C65747465';
wwv_flow_api.g_varchar2_table(48) := '727320666C6970206F7468657277697365290A2020202069662028642E7474207C7C20642E736929207B20726F77732E70757368285B4C2E73686966742C2028642E7474203F20642E7474202B20272027203A20272729202B2028642E7369203F20275C';
wwv_flow_api.g_varchar2_table(49) := '753230363627202B20642E7369202B202720E280932027202B2028642E736F207C7C20272729202B20275C753230363927203A202727295D293B207D0A2020202069662028642E6369207C7C20642E636F29207B20726F77732E70757368285B4C2E696E';
wwv_flow_api.g_varchar2_table(50) := '6F75742C2028642E6369207C7C2027E280942729202B202720E280932027202B2028642E636F207C7C2027E2809427295D293B207D0A2020202069662028642E776B29207B20726F77732E70757368285B4C2E776F726B65642C20686F75727328642E77';
wwv_flow_api.g_varchar2_table(51) := '6B29202B2028642E726571203F2027202F2027202B20686F75727328642E72657129203A202727295D293B207D0A2020202069662028642E6C61746529207B20726F77732E70757368285B4C2E6C6174654D696E2C204D6174682E726F756E6428642E6C';
wwv_flow_api.g_varchar2_table(52) := '61746529202B20272027202B204C2E6D696E5D293B207D0A2020202069662028642E6561726C7929207B20726F77732E70757368285B4C2E6561726C794D696E2C204D6174682E726F756E6428642E6561726C7929202B20272027202B204C2E6D696E5D';
wwv_flow_api.g_varchar2_table(53) := '293B207D0A2020202069662028642E6F7429207B20726F77732E70757368285B4C2E6F744D696E2C20686F75727328642E6F74295D293B207D0A2020202069662028642E6C7629207B20726F77732E70757368285B4C2E6C656176654D696E2C20686F75';
wwv_flow_api.g_varchar2_table(54) := '727328642E6C7629202B2028642E6C63203F2027202827202B20642E6C63202B20272927203A202727295D293B207D0A2020202069662028642E686F6C29207B20726F77732E70757368285B4C2E686F6C696461792C20642E686F6C5D293B207D0A2020';
wwv_flow_api.g_varchar2_table(55) := '202069662028642E706E29207B20726F77732E70757368285B4C2E70756E636865732C20642E706E5D293B207D0A2020202072657475726E20273C64697620636C6173733D226864722D632D646574223E3C64697620636C6173733D226864722D632D64';
wwv_flow_api.g_varchar2_table(56) := '65742D68223E3C7370616E20636C6173733D226864722D632D70696C6C22207374796C653D222D2D633A27202B2028434F4C4F52535B642E73745D207C7C2027233934613362382729202B2027223E27202B0A202020202020657363286E616D6529202B';
wwv_flow_api.g_varchar2_table(57) := '20273C2F7370616E3E3C623E27202B2065736328642E6429202B20273C2F623E3C627574746F6E20747970653D22627574746F6E2220636C6173733D226864722D632D782220617269612D6C6162656C3D2227202B20657363284C2E636C6F736529202B';
wwv_flow_api.g_varchar2_table(58) := '2027223EC3973C2F627574746F6E3E3C2F6469763E27202B0A202020202020273C646C3E27202B20726F77732E6D61702866756E6374696F6E20287229207B2072657475726E20273C64743E27202B2065736328725B305D29202B20273C2F64743E3C64';
wwv_flow_api.g_varchar2_table(59) := '64206469723D226C7472223E27202B2065736328725B315D29202B20273C2F64643E273B207D292E6A6F696E28272729202B20273C2F646C3E3C2F6469763E273B0A20207D0A0A202066756E6374696F6E206472617728656C2C206366672C2064617461';
wwv_flow_api.g_varchar2_table(60) := '29207B0A20202020766172204C203D205458545B6366672E6C616E675D3B0A2020202076617220796D203D20646174612E6D6F6E74682C2079203D202B796D2E736C69636528302C2034292C206D6F203D202B796D2E736C69636528352C2037293B0A20';
wwv_flow_api.g_varchar2_table(61) := '202020766172206E6176203D20273C64697620636C6173733D226864722D632D6E6176223E3C627574746F6E20747970653D22627574746F6E2220646174612D6E3D222D312220617269612D6C6162656C3D2227202B20657363284C2E7072657629202B';
wwv_flow_api.g_varchar2_table(62) := '2027223EE280B93C2F627574746F6E3E27202B0A202020202020273C623E27202B20657363284C2E6D6F6E7468735B6D6F202D20315D29202B20272027202B2079202B20273C2F623E3C627574746F6E20747970653D22627574746F6E2220646174612D';
wwv_flow_api.g_varchar2_table(63) := '6E3D22312220617269612D6C6162656C3D2227202B20657363284C2E6E65787429202B2027223EE280BA3C2F627574746F6E3E27202B0A202020202020273C627574746F6E20747970653D22627574746F6E2220646174612D6E3D22302220636C617373';
wwv_flow_api.g_varchar2_table(64) := '3D226864722D632D746F646179223E27202B20657363284C2E746F64617929202B20273C2F627574746F6E3E3C2F6469763E273B0A2020202069662028646174612E656D70747929207B0A202020202020656C2E696E6E657248544D4C203D20273C6469';
wwv_flow_api.g_varchar2_table(65) := '7620636C6173733D226864722D632D68656164223E27202B206E6176202B20273C2F6469763E3C64697620636C6173733D226864722D632D656D707479223E27202B20657363284C2E7069636B29202B20273C2F6469763E273B0A202020202020726574';
wwv_flow_api.g_varchar2_table(66) := '75726E2062696E6428656C2C206366672C20646174612C207B7D293B0A202020207D0A202020207661722065203D20646174612E656D70207C7C207B7D2C206E616D65203D20286366672E6C616E67203D3D3D2027656E2720262620652E6E616D655F65';
wwv_flow_api.g_varchar2_table(67) := '6E29203F20652E6E616D655F656E203A2028652E6E616D65207C7C20652E636F6465293B0A202020202F2F20783032206F6E6C79206B65657073206561636820706572736F6E2773207069637475726520617061727420696E207468652062726F777365';
wwv_flow_api.g_varchar2_table(68) := '722063616368653B207468652073657276657220646563696465732077686F2069732073686F776E0A202020207661722066616365203D20652E70686F746F202626206366672E70686F746F203D3D3D202759270A2020202020203F20273C696D672061';
wwv_flow_api.g_varchar2_table(69) := '6C743D2222207372633D2227202B2065736328617065782E7365727665722E706C7567696E55726C286366672E616A61782C207B207830313A202750484F544F272C207830323A20652E636F6465207D2929202B2027223E270A2020202020203A20273C';
wwv_flow_api.g_varchar2_table(70) := '623E27202B20696E697469616C286E616D6529202B20273C2F623E273B0A20202020766172206279446179203D207B7D3B0A2020202028646174612E64617973207C7C205B5D292E666F72456163682866756E6374696F6E20286429207B206279446179';
wwv_flow_api.g_varchar2_table(71) := '5B642E645D203D20643B207D293B0A20202020766172206669727374203D206E6577204461746528792C206D6F202D20312C2031292E67657444617928292C206C656164203D20286669727374202D2053544152545B6366672E7765656B5D202B203729';
wwv_flow_api.g_varchar2_table(72) := '202520373B0A2020202076617220636F756E74203D206E6577204461746528792C206D6F2C2030292E6765744461746528293B0A202020207661722068656164203D2027273B0A20202020666F7220287661722069203D20303B2069203C20373B20692B';
wwv_flow_api.g_varchar2_table(73) := '2B29207B2068656164202B3D20273C64697620636C6173733D226864722D632D7764223E27202B20657363284C2E646179735B2853544152545B6366672E7765656B5D202B206929202520375D29202B20273C2F6469763E273B207D0A20202020766172';
wwv_flow_api.g_varchar2_table(74) := '2063656C6C73203D2027273B0A20202020666F72202869203D20303B2069203C206C6561643B20692B2B29207B2063656C6C73202B3D20273C64697620636C6173733D226864722D632D64617920626C616E6B223E3C2F6469763E273B207D0A20202020';
wwv_flow_api.g_varchar2_table(75) := '666F722028766172206E203D20313B206E203C3D20636F756E743B206E2B2B29207B0A202020202020766172206B6579203D20796D6428792C206D6F2C206E292C2064203D2062794461795B6B65795D2C207374203D2064203F20642E7374203A202727';
wwv_flow_api.g_varchar2_table(76) := '3B0A202020202020766172206C6162656C203D2064203F20286366672E6C616E67203D3D3D2027617227203F2028642E6172207C7C20737429203A2028642E656E207C7C2073742929203A2027273B0A20202020202063656C6C73202B3D20273C627574';
wwv_flow_api.g_varchar2_table(77) := '746F6E20747970653D22627574746F6E2220636C6173733D226864722D632D64617927202B20286B6579203D3D3D20646174612E746F646179203F202720746F64617927203A20272729202B202864203F202727203A2027206E6F646174612729202B0A';
wwv_flow_api.g_varchar2_table(78) := '2020202020202020272220646174612D643D2227202B206B6579202B202722207374796C653D222D2D633A27202B2028434F4C4F52535B73745D207C7C20277472616E73706172656E742729202B20272227202B202864203F202727203A202720646973';
wwv_flow_api.g_varchar2_table(79) := '61626C65642729202B20273E27202B0A2020202020202020273C7370616E20636C6173733D226864722D632D6E223E27202B206E202B20273C2F7370616E3E27202B0A20202020202020202864203F20273C7370616E20636C6173733D226864722D632D';
wwv_flow_api.g_varchar2_table(80) := '7374223E27202B20657363286C6162656C29202B20273C2F7370616E3E27202B0A2020202020202020202028642E6369207C7C20642E636F203F20273C7370616E20636C6173733D226864722D632D74223E5C753230363627202B2065736328642E6369';
wwv_flow_api.g_varchar2_table(81) := '207C7C2027E280942729202B2028642E636F203F202720E280932027202B2065736328642E636F29203A20272729202B20275C75323036393C2F7370616E3E27203A20272729203A20272729202B0A2020202020202020273C2F627574746F6E3E273B0A';
wwv_flow_api.g_varchar2_table(82) := '202020207D0A20202020656C2E696E6E657248544D4C203D20273C64697620636C6173733D226864722D632D68656164223E3C64697620636C6173733D226864722D632D77686F223E3C7370616E20636C6173733D226864722D632D7068223E27202B20';
wwv_flow_api.g_varchar2_table(83) := '66616365202B20273C2F7370616E3E3C7370616E3E3C62206469723D226175746F223E27202B0A202020202020657363286E616D6529202B20273C2F623E3C736D616C6C206469723D226175746F223E27202B20657363285B652E636F64652C20652E64';
wwv_flow_api.g_varchar2_table(84) := '6570745D2E66696C74657228426F6F6C65616E292E6A6F696E282720C2B720272929202B20273C2F736D616C6C3E3C2F7370616E3E3C2F6469763E27202B206E6176202B20273C2F6469763E27202B0A20202020202073756D6D617279284C2C20646174';
wwv_flow_api.g_varchar2_table(85) := '612E64617973207C7C205B5D29202B0A2020202020202828646174612E64617973207C7C205B5D292E6C656E677468203F202727203A20273C64697620636C6173733D226864722D632D656D707479223E27202B20657363284C2E6E6F6E6529202B2027';
wwv_flow_api.g_varchar2_table(86) := '3C2F6469763E2729202B0A202020202020273C64697620636C6173733D226864722D632D67726964223E27202B2068656164202B2063656C6C73202B20273C2F6469763E3C64697620636C6173733D226864722D632D6D6F7265223E3C2F6469763E273B';
wwv_flow_api.g_varchar2_table(87) := '0A2020202062696E6428656C2C206366672C20646174612C206279446179293B0A20207D0A0A202066756E6374696F6E2062696E6428656C2C206366672C20646174612C20627944617929207B0A20202020766172204C203D205458545B6366672E6C61';
wwv_flow_api.g_varchar2_table(88) := '6E675D3B0A2020202041727261792E70726F746F747970652E666F72456163682E63616C6C28656C2E717565727953656C6563746F72416C6C28275B646174612D6E5D27292C2066756E6374696F6E20286229207B0A202020202020622E6F6E636C6963';
wwv_flow_api.g_varchar2_table(89) := '6B203D2066756E6374696F6E202829207B0A2020202020202020766172206E203D202B622E6765744174747269627574652827646174612D6E27293B0A20202020202020206366672E6D6F6E7468203D206E203D3D3D2030203F20646174612E746F6461';
wwv_flow_api.g_varchar2_table(90) := '792E736C69636528302C203729203A206164644D6F6E746828646174612E6D6F6E74682C206E293B0A20202020202020206366672E6C6F616428293B0A2020202020207D3B0A202020207D293B0A20202020766172206D6F7265203D20656C2E71756572';
wwv_flow_api.g_varchar2_table(91) := '7953656C6563746F7228272E6864722D632D6D6F726527293B0A2020202041727261792E70726F746F747970652E666F72456163682E63616C6C28656C2E717565727953656C6563746F72416C6C28272E6864722D632D6461795B646174612D645D2729';
wwv_flow_api.g_varchar2_table(92) := '2C2066756E6374696F6E20286229207B0A202020202020622E6F6E636C69636B203D2066756E6374696F6E202829207B0A20202020202020207661722064203D2062794461795B622E6765744174747269627574652827646174612D6427295D3B0A2020';
wwv_flow_api.g_varchar2_table(93) := '202020202020696620282164207C7C20216D6F726529207B2072657475726E3B207D0A202020202020202041727261792E70726F746F747970652E666F72456163682E63616C6C28656C2E717565727953656C6563746F72416C6C28272E6864722D632D';
wwv_flow_api.g_varchar2_table(94) := '6461792E73656C27292C2066756E6374696F6E20287829207B20782E636C6173734C6973742E72656D6F7665282773656C27293B207D293B0A2020202020202020622E636C6173734C6973742E616464282773656C27293B0A20202020202020206D6F72';
wwv_flow_api.g_varchar2_table(95) := '652E696E6E657248544D4C203D2064657461696C284C2C206366672E6C616E672C2064293B0A20202020202020206D6F72652E717565727953656C6563746F7228272E6864722D632D7827292E6F6E636C69636B203D2066756E6374696F6E202829207B';
wwv_flow_api.g_varchar2_table(96) := '206D6F72652E696E6E657248544D4C203D2027273B20622E636C6173734C6973742E72656D6F7665282773656C27293B207D3B0A2020202020207D3B0A202020207D293B0A20207D0A0A202066756E6374696F6E20696E69742869642C20616A61782C20';
wwv_flow_api.g_varchar2_table(97) := '6974656D732C206D6F6E74684974656D2C206C616E672C207765656B2C2070686F746F29207B0A2020202076617220656C203D20646F63756D656E742E676574456C656D656E7442794964286964293B0A202020206966202821656C29207B2072657475';
wwv_flow_api.g_varchar2_table(98) := '726E3B207D0A20202020696620286C616E6720213D3D2027415227202626206C616E6720213D3D2027454E2729207B0A2020202020206C616E67203D202F5E61722F692E7465737428646F63756D656E742E646F63756D656E74456C656D656E742E6C61';
wwv_flow_api.g_varchar2_table(99) := '6E67207C7C20272729203F2027415227203A2027454E273B0A202020207D0A2020202076617220636667203D207B20616A61783A20616A61782C206C616E673A206C616E672E746F4C6F7765724361736528292C207765656B3A2053544152545B776565';
wwv_flow_api.g_varchar2_table(100) := '6B5D20213D3D20756E646566696E6564203F207765656B203A2027534154272C2070686F746F3A2070686F746F2C206D6F6E74683A206E756C6C207D3B0A20202020656C2E7365744174747269627574652827646972272C206366672E6C616E67203D3D';
wwv_flow_api.g_varchar2_table(101) := '3D2027617227203F202772746C27203A20276C747227293B0A2020202076617220736571203D20303B0A202020206366672E6C6F6164203D2066756E6374696F6E202829207B0A202020202020766172206D696E65203D202B2B7365713B0A2020202020';
wwv_flow_api.g_varchar2_table(102) := '20766172206F707473203D207B2064617461547970653A20276A736F6E272C20737563636573733A2066756E6374696F6E20286429207B0A2020202020202020696620286D696E6520213D3D2073657129207B2072657475726E3B207D2020202F2F2061';
wwv_flow_api.g_varchar2_table(103) := '6E206F6C64657220616E73776572206172726976696E67206C6174650A2020202020202020696620286420262620642E6661696C75726529207B20656C2E696E6E657248544D4C203D20273C64697620636C6173733D226864722D632D657272223E2720';
wwv_flow_api.g_varchar2_table(104) := '2B20657363285458545B6366672E6C616E675D2E6572726F7229202B20273A2027202B2065736328642E6661696C75726529202B20273C2F6469763E273B2072657475726E3B207D0A20202020202020206472617728656C2C206366672C2064207C7C20';
wwv_flow_api.g_varchar2_table(105) := '7B7D293B0A2020202020207D2C206572726F723A2066756E6374696F6E202829207B0A2020202020202020696620286D696E65203D3D3D2073657129207B20656C2E696E6E657248544D4C203D20273C64697620636C6173733D226864722D632D657272';
wwv_flow_api.g_varchar2_table(106) := '223E27202B20657363285458545B6366672E6C616E675D2E6572726F7229202B20273C2F6469763E273B207D0A2020202020207D207D3B0A2020202020207661722064617461203D207B207830313A206366672E6D6F6E7468207C7C202727207D3B0A20';
wwv_flow_api.g_varchar2_table(107) := '2020202020696620286974656D7329207B20646174612E706167654974656D73203D206974656D732E73706C697428272C27292E6D61702866756E6374696F6E20287829207B2072657475726E20272327202B20782E7472696D28293B207D292E6A6F69';
wwv_flow_api.g_varchar2_table(108) := '6E28272C27293B207D0A202020202020617065782E7365727665722E706C7567696E28616A61782C20646174612C206F707473293B0A202020207D3B0A202020206366672E6C6F616428293B0A20202020696620286974656D7329207B0A202020202020';
wwv_flow_api.g_varchar2_table(109) := '6974656D732E73706C697428272C27292E666F72456163682866756E6374696F6E2028697429207B0A2020202020202020617065782E6A517565727928272327202B2069742E7472696D28292E7265706C616365282F5B5E5C77245D2F672C2027272929';
wwv_flow_api.g_varchar2_table(110) := '2E6F6E28276368616E6765272C2066756E6374696F6E202829207B0A20202020202020202020696620286D6F6E74684974656D2026262069742E7472696D2829203D3D3D206D6F6E74684974656D29207B206366672E6D6F6E7468203D206E756C6C3B20';
wwv_flow_api.g_varchar2_table(111) := '7D2020202F2F2074686520706167652773206D6F6E74682077696E730A202020202020202020206366672E6C6F616428293B0A20202020202020207D293B0A2020202020207D293B0A202020207D0A20202020617065782E6A517565727928656C292E63';
wwv_flow_api.g_varchar2_table(112) := '6C6F7365737428272E742D526567696F6E2C202E612D526567696F6E27292E6F6E28276170657872656672657368272C206366672E6C6F6164293B0A20207D0A202072657475726E207B20696E69743A20696E6974207D3B0A7D2829293B0A';
end;
/
prompt --application/shared_components/plugins/region_type/com_hader_employee_calendar/hader-calendar.js
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(91734300000018)
,p_plugin_id=>wwv_flow_api.id(91734300000001)
,p_file_name=>'hader-calendar.js'
,p_mime_type=>'application/javascript'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_api.varchar2_to_blob(wwv_flow_api.g_varchar2_table)
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '2F2A20486164657220656D706C6F79656520617474656E64616E63652063616C656E646172202A2F0A2E6864722D63207B202D2D68632D7465616C3A20233065386638363B202D2D68632D696E6B3A20233133323032633B202D2D68632D6D757465643A';
wwv_flow_api.g_varchar2_table(2) := '20233562366237623B202D2D68632D6C696E653A20236536656165663B20636F6C6F723A20766172282D2D68632D696E6B293B0A2020666F6E742D76617269616E742D6E756D657269633A20746162756C61722D6E756D733B206D696E2D686569676874';
wwv_flow_api.g_varchar2_table(3) := '3A2031323070783B207D0A2E6864722D632D6C6F6164207B206865696768743A2031363070783B20626F726465722D7261646975733A20313670783B206261636B67726F756E643A206C696E6561722D6772616469656E742839306465672C2023663166';
wwv_flow_api.g_varchar2_table(4) := '336636203235252C2023653765626630203530252C202366316633663620373525293B0A20206261636B67726F756E642D73697A653A203230302520313030253B20616E696D6174696F6E3A206864722D632D736820312E327320696E66696E69746520';
wwv_flow_api.g_varchar2_table(5) := '6C696E6561723B207D0A406B65796672616D6573206864722D632D7368207B20746F207B206261636B67726F756E642D706F736974696F6E3A202D3230302520303B207D207D0A2E6864722D632D68656164207B20646973706C61793A20666C65783B20';
wwv_flow_api.g_varchar2_table(6) := '666C65782D777261703A20777261703B20616C69676E2D6974656D733A2063656E7465723B206A7573746966792D636F6E74656E743A2073706163652D6265747765656E3B206761703A20313270783B206D617267696E2D626F74746F6D3A2031327078';
wwv_flow_api.g_varchar2_table(7) := '3B207D0A2E6864722D632D77686F207B20646973706C61793A20666C65783B20616C69676E2D6974656D733A2063656E7465723B206761703A20313270783B206D696E2D77696474683A20303B207D0A2E6864722D632D77686F203E207370616E3A6C61';
wwv_flow_api.g_varchar2_table(8) := '73742D6368696C64207B20646973706C61793A20666C65783B20666C65782D646972656374696F6E3A20636F6C756D6E3B206D696E2D77696474683A20303B207D0A2E6864722D632D77686F2062207B20666F6E742D73697A653A20313670783B206F76';
wwv_flow_api.g_varchar2_table(9) := '6572666C6F773A2068696464656E3B20746578742D6F766572666C6F773A20656C6C69707369733B2077686974652D73706163653A206E6F777261703B207D0A2E6864722D632D77686F20736D616C6C207B20636F6C6F723A20766172282D2D68632D6D';
wwv_flow_api.g_varchar2_table(10) := '75746564293B20666F6E742D73697A653A20313270783B207D0A2E6864722D632D7068207B2077696474683A20343870783B206865696768743A20343870783B20666C65783A206E6F6E653B20626F726465722D7261646975733A203530253B20626163';
wwv_flow_api.g_varchar2_table(11) := '6B67726F756E643A20236536663466323B20636F6C6F723A20766172282D2D68632D7465616C293B20646973706C61793A20677269643B0A2020706C6163652D6974656D733A2063656E7465723B206F766572666C6F773A2068696464656E3B20666F6E';
wwv_flow_api.g_varchar2_table(12) := '742D73697A653A20323070783B207D0A2E6864722D632D706820696D67207B2077696474683A20313030253B206865696768743A20313030253B206F626A6563742D6669743A20636F7665723B207D0A2E6864722D632D6E6176207B20646973706C6179';
wwv_flow_api.g_varchar2_table(13) := '3A20666C65783B20616C69676E2D6974656D733A2063656E7465723B206761703A203670783B207D0A2E6864722D632D6E61762062207B206D696E2D77696474683A2031323070783B20746578742D616C69676E3A2063656E7465723B20666F6E742D73';
wwv_flow_api.g_varchar2_table(14) := '697A653A20313570783B207D0A2E6864722D632D6E617620627574746F6E207B20626F726465723A2031707820736F6C696420766172282D2D68632D6C696E65293B206261636B67726F756E643A20236666663B20636F6C6F723A20766172282D2D6863';
wwv_flow_api.g_varchar2_table(15) := '2D696E6B293B20626F726465722D7261646975733A20313070783B206865696768743A20333270783B0A20206D696E2D77696474683A20333270783B2070616464696E673A203020313070783B20666F6E742D73697A653A20313870783B206C696E652D';
wwv_flow_api.g_varchar2_table(16) := '6865696768743A20313B20637572736F723A20706F696E7465723B207D0A2E6864722D632D6E617620627574746F6E2E6864722D632D746F646179207B20666F6E742D73697A653A20313270783B207D0A2E6864722D632D6E617620627574746F6E3A68';
wwv_flow_api.g_varchar2_table(17) := '6F766572207B206261636B67726F756E643A20236633663666383B207D0A2E6864722D635B6469723D72746C5D202E6864722D632D6E617620627574746F6E5B646174612D6E5D207B207472616E73666F726D3A207363616C6558282D31293B207D0A2E';
wwv_flow_api.g_varchar2_table(18) := '6864722D635B6469723D72746C5D202E6864722D632D6E617620627574746F6E2E6864722D632D746F646179207B207472616E73666F726D3A206E6F6E653B207D0A2E6864722D632D73756D207B20646973706C61793A20677269643B20677269642D74';
wwv_flow_api.g_varchar2_table(19) := '656D706C6174652D636F6C756D6E733A20726570656174286175746F2D6669742C206D696E6D61782831323070782C2031667229293B206761703A203870783B206D617267696E2D626F74746F6D3A20313270783B207D0A2E6864722D632D6368697020';
wwv_flow_api.g_varchar2_table(20) := '7B20706F736974696F6E3A2072656C61746976653B206261636B67726F756E643A20236636663866613B20626F726465722D7261646975733A20313470783B2070616464696E673A203130707820313270783B20646973706C61793A20666C65783B2066';
wwv_flow_api.g_varchar2_table(21) := '6C65782D646972656374696F6E3A20636F6C756D6E3B207D0A2E6864722D632D636869702069207B20706F736974696F6E3A206162736F6C7574653B20696E7365742D696E6C696E652D656E643A20313270783B20746F703A20313370783B2077696474';
wwv_flow_api.g_varchar2_table(22) := '683A203870783B206865696768743A203870783B20626F726465722D7261646975733A203530253B207D0A2E6864722D632D636869702062207B20666F6E742D73697A653A20313870783B206C696E652D6865696768743A20312E32353B207D0A2E6864';
wwv_flow_api.g_varchar2_table(23) := '722D632D63686970206220736D616C6C207B20666F6E742D73697A653A20313170783B20636F6C6F723A20766172282D2D68632D6D75746564293B20666F6E742D7765696768743A203530303B207D0A2E6864722D632D63686970207370616E207B2063';
wwv_flow_api.g_varchar2_table(24) := '6F6C6F723A20766172282D2D68632D6D75746564293B20666F6E742D73697A653A20313270783B207D0A2E6864722D632D67726964207B20646973706C61793A20677269643B20677269642D74656D706C6174652D636F6C756D6E733A20726570656174';
wwv_flow_api.g_varchar2_table(25) := '28372C206D696E6D617828302C2031667229293B206761703A203670783B207D0A2E6864722D632D7764207B20746578742D616C69676E3A2063656E7465723B20666F6E742D73697A653A20313270783B20636F6C6F723A20766172282D2D68632D6D75';
wwv_flow_api.g_varchar2_table(26) := '746564293B2070616464696E673A203270782030203470783B207D0A2E6864722D632D646179207B20706F736974696F6E3A2072656C61746976653B206D696E2D6865696768743A20373270783B20626F726465723A2031707820736F6C696420766172';
wwv_flow_api.g_varchar2_table(27) := '282D2D68632D6C696E65293B20626F726465722D7261646975733A20313270783B206261636B67726F756E643A20236666663B0A202070616464696E673A20367078203770782036707820313070783B20646973706C61793A20666C65783B20666C6578';
wwv_flow_api.g_varchar2_table(28) := '2D646972656374696F6E3A20636F6C756D6E3B20616C69676E2D6974656D733A20666C65782D73746172743B206761703A203270783B20746578742D616C69676E3A2073746172743B0A2020666F6E743A20696E68657269743B20636F6C6F723A20696E';
wwv_flow_api.g_varchar2_table(29) := '68657269743B20637572736F723A20706F696E7465723B206F766572666C6F773A2068696464656E3B207D0A2E6864722D635B6469723D72746C5D202E6864722D632D646179207B2070616464696E673A20367078203130707820367078203770783B20';
wwv_flow_api.g_varchar2_table(30) := '7D0A2E6864722D632D6461793A3A6265666F7265207B20636F6E74656E743A2022223B20706F736974696F6E3A206162736F6C7574653B20696E7365742D626C6F636B3A20303B20696E7365742D696E6C696E652D73746172743A20303B207769647468';
wwv_flow_api.g_varchar2_table(31) := '3A203470783B206261636B67726F756E643A20766172282D2D63293B207D0A2E6864722D632D6461792E626C616E6B207B20626F726465723A20303B206261636B67726F756E643A207472616E73706172656E743B20637572736F723A2064656661756C';
wwv_flow_api.g_varchar2_table(32) := '743B207D0A2E6864722D632D6461792E626C616E6B3A3A6265666F72652C202E6864722D632D6461792E6E6F646174613A3A6265666F7265207B20646973706C61793A206E6F6E653B207D0A2E6864722D632D6461792E6E6F64617461207B206261636B';
wwv_flow_api.g_varchar2_table(33) := '67726F756E643A20236661666266633B20636F6C6F723A20236233626363363B20637572736F723A2064656661756C743B207D0A2E6864722D632D6461793A6E6F74282E6E6F64617461293A6E6F74282E626C616E6B293A686F766572207B20626F782D';
wwv_flow_api.g_varchar2_table(34) := '736861646F773A2030203270782038707820726762612831392C2033322C2034342C202E3038293B207D0A2E6864722D632D6461792E746F646179207B20626F726465722D636F6C6F723A20766172282D2D68632D7465616C293B20626F782D73686164';
wwv_flow_api.g_varchar2_table(35) := '6F773A2030203020302031707820766172282D2D68632D7465616C2920696E7365743B207D0A2E6864722D632D6461792E73656C207B206261636B67726F756E643A20236565663866363B207D0A2E6864722D632D6E207B20666F6E742D776569676874';
wwv_flow_api.g_varchar2_table(36) := '3A203730303B20666F6E742D73697A653A20313370783B207D0A2E6864722D632D7374207B20666F6E742D73697A653A20313170783B20636F6C6F723A20766172282D2D63293B20666F6E742D7765696768743A203630303B206D61782D77696474683A';
wwv_flow_api.g_varchar2_table(37) := '20313030253B206F766572666C6F773A2068696464656E3B20746578742D6F766572666C6F773A20656C6C69707369733B2077686974652D73706163653A206E6F777261703B0A202066696C7465723A206272696768746E657373282E3835293B207D0A';
wwv_flow_api.g_varchar2_table(38) := '2E6864722D632D74207B20666F6E742D73697A653A20313170783B20636F6C6F723A20766172282D2D68632D6D75746564293B2077686974652D73706163653A206E6F777261703B207D0A2E6864722D632D656D707479207B20636F6C6F723A20766172';
wwv_flow_api.g_varchar2_table(39) := '282D2D68632D6D75746564293B206261636B67726F756E643A20236636663866613B20626F726465722D7261646975733A20313270783B2070616464696E673A20313470783B206D617267696E2D626F74746F6D3A20313070783B20746578742D616C69';
wwv_flow_api.g_varchar2_table(40) := '676E3A2063656E7465723B207D0A2E6864722D632D657272207B20636F6C6F723A20236234323331383B206261636B67726F756E643A20236664656365613B20626F726465722D7261646975733A20313270783B2070616464696E673A20313270783B20';
wwv_flow_api.g_varchar2_table(41) := '7D0A2E6864722D632D646574207B206D617267696E2D746F703A20313270783B20626F726465723A2031707820736F6C696420766172282D2D68632D6C696E65293B20626F726465722D7261646975733A20313470783B2070616464696E673A20313270';
wwv_flow_api.g_varchar2_table(42) := '7820313470783B206261636B67726F756E643A20236666663B207D0A2E6864722D632D6465742D68207B20646973706C61793A20666C65783B20616C69676E2D6974656D733A2063656E7465723B206761703A20313070783B206D617267696E2D626F74';
wwv_flow_api.g_varchar2_table(43) := '746F6D3A203870783B207D0A2E6864722D632D6465742D682062207B20666C65783A20313B207D0A2E6864722D632D70696C6C207B206261636B67726F756E643A20236631663466363B206261636B67726F756E643A20636F6C6F722D6D697828696E20';
wwv_flow_api.g_varchar2_table(44) := '737267622C20766172282D2D6329203134252C2023666666293B20636F6C6F723A20766172282D2D63293B20626F726465722D7261646975733A2039393970783B2070616464696E673A2033707820313070783B20666F6E742D73697A653A2031327078';
wwv_flow_api.g_varchar2_table(45) := '3B20666F6E742D7765696768743A203730303B207D0A2E6864722D632D78207B20626F726465723A20303B206261636B67726F756E643A20236631663466363B20626F726465722D7261646975733A203530253B2077696474683A20323870783B206865';
wwv_flow_api.g_varchar2_table(46) := '696768743A20323870783B20666F6E742D73697A653A20313870783B206C696E652D6865696768743A20313B20637572736F723A20706F696E7465723B207D0A2E6864722D632D64657420646C207B20646973706C61793A20677269643B20677269642D';
wwv_flow_api.g_varchar2_table(47) := '74656D706C6174652D636F6C756D6E733A206D61782D636F6E74656E74203166723B206761703A2036707820313470783B206D617267696E3A20303B20666F6E742D73697A653A20313370783B207D0A2E6864722D632D646574206474207B20636F6C6F';
wwv_flow_api.g_varchar2_table(48) := '723A20766172282D2D68632D6D75746564293B207D0A2E6864722D632D646574206464207B206D617267696E3A20303B20746578742D616C69676E3A2073746172743B207D0A2E6864722D635B6469723D72746C5D202E6864722D632D64657420646420';
wwv_flow_api.g_varchar2_table(49) := '7B20746578742D616C69676E3A2072696768743B207D0A406D6564696120286D61782D77696474683A20363430707829207B0A20202E6864722D632D646179207B206D696E2D6865696768743A20343670783B2070616464696E673A2034707820347078';
wwv_flow_api.g_varchar2_table(50) := '20347078203770783B207D0A20202E6864722D635B6469723D72746C5D202E6864722D632D646179207B2070616464696E673A203470782037707820347078203470783B207D0A20202E6864722D632D73742C202E6864722D632D74207B20646973706C';
wwv_flow_api.g_varchar2_table(51) := '61793A206E6F6E653B207D0A20202E6864722D632D6461793A6E6F74282E6E6F64617461293A6E6F74282E626C616E6B293A3A6166746572207B20636F6E74656E743A2022223B2077696474683A203870783B206865696768743A203870783B20626F72';
wwv_flow_api.g_varchar2_table(52) := '6465722D7261646975733A203530253B206261636B67726F756E643A20766172282D2D63293B206D617267696E2D746F703A203270783B207D0A20202E6864722D632D67726964207B206761703A203470783B207D0A20202E6864722D632D73756D207B';
wwv_flow_api.g_varchar2_table(53) := '20677269642D74656D706C6174652D636F6C756D6E733A2072657065617428332C20316672293B207D0A20202E6864722D632D636869702062207B20666F6E742D73697A653A20313570783B207D0A7D0A';
end;
/
prompt --application/shared_components/plugins/region_type/com_hader_employee_calendar/hader-calendar.css
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(91734300000019)
,p_plugin_id=>wwv_flow_api.id(91734300000001)
,p_file_name=>'hader-calendar.css'
,p_mime_type=>'text/css'
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
