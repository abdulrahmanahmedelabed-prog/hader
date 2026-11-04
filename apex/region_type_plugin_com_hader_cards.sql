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
--     PLUGIN: COM.HADER.CARDS
--   Manifest End
--   Version:         19.2.0.00.18
--   Instance ID:     1
--

prompt --application/shared_components/plugins/region_type/com_hader_cards
begin
wwv_flow_api.create_plugin(
 p_id=>wwv_flow_api.id(91734900000001)
,p_plugin_type=>'REGION TYPE'
,p_name=>'COM.HADER.CARDS'
,p_display_name=>'Hader Cards (حاضر - بطاقات)'
,p_supported_ui_types=>'DESKTOP:JQM_SMARTPHONE'
,p_javascript_file_urls=>'#PLUGIN_FILES#hader-cards.js'
,p_css_file_urls=>'#PLUGIN_FILES#hader-cards.css'
,p_plsql_code=>wwv_flow_string.join(wwv_flow_t_varchar2(
'-- Hader cards (region plug-in). APEX 19.2 and later.',
'-- The rows of the region''s own SQL query (Source in Page Designer) as cards: a picture, a title, a line under it,',
'-- a big value, details and a link, each from the column chosen for it in the region''s attributes. It refreshes by',
'-- itself and on a Refresh action, the page items in "Page Items to Submit" bound in the query, like a classic report.',
'',
'function col (p_ctx in apex_exec.t_context, p_name in varchar2) return pls_integer is',
'begin',
'  if p_name is null then',
'    return null;',
'  end if;',
'  return apex_exec.get_column_position(p_ctx, p_name);',
'end col;',
'',
'function val (p_ctx in apex_exec.t_context, p_pos in pls_integer) return varchar2 is',
'begin',
'  if p_pos is null then',
'    return null;',
'  end if;',
'  return apex_exec.get_varchar2(p_ctx, p_pos);',
'end val;',
'',
'function render (',
'  p_region              in apex_plugin.t_region,',
'  p_plugin              in apex_plugin.t_plugin,',
'  p_is_printer_friendly in boolean )',
'  return apex_plugin.t_region_render_result',
'is',
'  l_id varchar2(255) := nvl(p_region.static_id, ''R'' || p_region.id);',
'begin',
'  sys.htp.p(''<div id="'' || apex_escape.html_attribute(l_id) || ''_hdr" class="hdr-cards hdr-cards-'' ||',
'            lower(nvl(p_region.attribute_14, ''DARK'')) || '' hdr-cards-'' || lower(nvl(p_region.attribute_15, ''STRIP'')) ||',
'            ''" style="--hdr-card-w:'' || to_number(nvl(p_region.attribute_16, ''150'')) || ''px"></div>'');',
'  apex_javascript.add_onload_code(',
'    ''hdrCards.init('' ||',
'    apex_javascript.add_value(l_id) ||',
'    apex_javascript.add_value(apex_plugin.get_ajax_identifier) ||',
'    apex_javascript.add_value(apex_plugin_util.page_item_names_to_jquery(p_region.ajax_items_to_submit)) ||',
'    apex_javascript.add_value(case when nvl(p_region.attribute_10, ''Y'') = ''Y'' then p_region.name end) ||   -- heading',
'    apex_javascript.add_value(p_region.attribute_11) ||                                                 -- heading link',
'    apex_javascript.add_value(p_region.attribute_12) ||                                                 -- its text',
'    apex_javascript.add_value(to_number(nvl(p_region.attribute_13, ''30''))) ||                           -- refresh',
'    apex_javascript.add_value(p_region.attribute_07) ||                                                 -- photo process',
'    apex_javascript.add_value(p_region.no_data_found_message, false) ||',
'    '');'');',
'  return null;',
'end render;',
'',
'function ajax (',
'  p_region in apex_plugin.t_region,',
'  p_plugin in apex_plugin.t_plugin )',
'  return apex_plugin.t_region_ajax_result',
'is',
'  l_ctx apex_exec.t_context;',
'  l_title pls_integer; l_sub pls_integer; l_value pls_integer; l_meta pls_integer;',
'  l_img pls_integer; l_photo pls_integer; l_link pls_integer; l_state pls_integer;',
'begin',
'  l_ctx := apex_exec.open_query_context(',
'             p_location  => apex_exec.c_location_local_db,',
'             p_sql_query => p_region.source,',
'             p_max_rows  => nvl(p_region.fetched_rows, 50));',
'  l_title := col(l_ctx, p_region.attribute_01);',
'  l_sub   := col(l_ctx, p_region.attribute_02);',
'  l_value := col(l_ctx, p_region.attribute_03);',
'  l_meta  := col(l_ctx, p_region.attribute_04);',
'  l_img   := col(l_ctx, p_region.attribute_05);',
'  l_photo := col(l_ctx, p_region.attribute_06);',
'  l_link  := col(l_ctx, p_region.attribute_08);',
'  l_state := col(l_ctx, p_region.attribute_09);',
'  apex_json.open_object;',
'  apex_json.open_array(''rows'');',
'  while apex_exec.next_row(l_ctx) loop',
'    apex_json.open_object;',
'    apex_json.write(''title'', val(l_ctx, l_title));',
'    apex_json.write(''sub'', val(l_ctx, l_sub));',
'    apex_json.write(''value'', val(l_ctx, l_value));',
'    apex_json.write(''meta'', val(l_ctx, l_meta));',
'    apex_json.write(''img'', val(l_ctx, l_img));',
'    apex_json.write(''photo'', val(l_ctx, l_photo));',
'    apex_json.write(''link'', val(l_ctx, l_link));',
'    apex_json.write(''state'', lower(val(l_ctx, l_state)));',
'    apex_json.close_object;',
'  end loop;',
'  apex_json.close_array;',
'  apex_json.close_object;',
'  apex_exec.close(l_ctx);',
'  return null;',
'exception when others then',
'  apex_exec.close(l_ctx);',
'  apex_json.free_output;',
'  sys.htp.init;   -- drop the half-written JSON',
'  apex_json.open_object;',
'  apex_json.write(''failure'', sqlerrm);   -- not ''error'': apex.server takes that one for its own',
'  apex_json.close_object;',
'  return null;',
'end ajax;'))
,p_api_version=>1
,p_render_function=>'render'
,p_ajax_function=>'ajax'
,p_standard_attributes=>'SOURCE_SQL:AJAX_ITEMS_TO_SUBMIT:FETCHED_ROWS:NO_DATA_FOUND_MESSAGE'
,p_sql_min_column_count=>1
,p_substitute_attributes=>true
,p_subscribe_plugin_settings=>true
,p_help_text=>'The rows of the region''s own SQL query as cards — a picture, a title, a line under it, a big value, details and a link — each from the column chosen for it below, like a classic report with a card template. It reads the rows again every few seconds and on a Refresh action; the page items in Page Items to Submit can be used as binds in the query. Nothing from the query is shown as HTML. Example (the latest punches in Hader for Oracle APEX): select EMP_CODE, FULL_NAME, to_char(PUNCH_TIME, ''HH24:MI'') AT, DEVICE_SN from HADER_PUNCHES join HDR_EMPLOYEES using (EMP_CODE) where PUNCH_TIME >= trunc(sysdate) order by PUNCH_TIME desc'
,p_version_identifier=>'1.3'
,p_files_version=>71852
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(91734900000002)
,p_plugin_id=>wwv_flow_api.id(91734900000001)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>1
,p_display_sequence=>10
,p_prompt=>'Title column'
,p_attribute_type=>'REGION SOURCE COLUMN'
,p_is_required=>true
,p_column_data_types=>'VARCHAR2:NUMBER:DATE:TIMESTAMP:TIMESTAMP_TZ:TIMESTAMP_LTZ'
,p_is_translatable=>false
,p_help_text=>'The card''s heading (a name).'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(91734900000003)
,p_plugin_id=>wwv_flow_api.id(91734900000001)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>2
,p_display_sequence=>20
,p_prompt=>'Subtitle column'
,p_attribute_type=>'REGION SOURCE COLUMN'
,p_is_required=>false
,p_column_data_types=>'VARCHAR2:NUMBER:DATE:TIMESTAMP:TIMESTAMP_TZ:TIMESTAMP_LTZ'
,p_is_translatable=>false
,p_help_text=>'A smaller line under the title (a number, a code).'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(91734900000004)
,p_plugin_id=>wwv_flow_api.id(91734900000001)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>3
,p_display_sequence=>30
,p_prompt=>'Value column'
,p_attribute_type=>'REGION SOURCE COLUMN'
,p_is_required=>false
,p_column_data_types=>'VARCHAR2:NUMBER:DATE:TIMESTAMP:TIMESTAMP_TZ:TIMESTAMP_LTZ'
,p_is_translatable=>false
,p_help_text=>'The big value of the card (a time, a count).'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(91734900000005)
,p_plugin_id=>wwv_flow_api.id(91734900000001)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>4
,p_display_sequence=>40
,p_prompt=>'Details column'
,p_attribute_type=>'REGION SOURCE COLUMN'
,p_is_required=>false
,p_column_data_types=>'VARCHAR2:NUMBER:DATE:TIMESTAMP:TIMESTAMP_TZ:TIMESTAMP_LTZ'
,p_is_translatable=>false
,p_help_text=>'A last small line (a state, a place).'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(91734900000006)
,p_plugin_id=>wwv_flow_api.id(91734900000001)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>5
,p_display_sequence=>50
,p_prompt=>'Image URL column'
,p_attribute_type=>'REGION SOURCE COLUMN'
,p_is_required=>false
,p_column_data_types=>'VARCHAR2'
,p_is_translatable=>false
,p_help_text=>'A picture''s address (https://..., wwv_flow.show?..., f?p=...). Other addresses are not used.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(91734900000007)
,p_plugin_id=>wwv_flow_api.id(91734900000001)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>6
,p_display_sequence=>60
,p_prompt=>'Photo by employee number column'
,p_attribute_type=>'REGION SOURCE COLUMN'
,p_is_required=>false
,p_column_data_types=>'VARCHAR2:NUMBER'
,p_is_translatable=>false
,p_help_text=>'The employee number whose picture the application process below returns (x01). Used when there is no image URL column.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(91734900000008)
,p_plugin_id=>wwv_flow_api.id(91734900000001)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>7
,p_display_sequence=>70
,p_prompt=>'Photo application process'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_default_value=>'HDR_PHOTO'
,p_display_length=>30
,p_max_length=>255
,p_is_translatable=>false
,p_help_text=>'The application process that returns an employee''s picture for the number in x01 (HDR_PHOTO in Hader''s application).'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(91734900000009)
,p_plugin_id=>wwv_flow_api.id(91734900000001)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>8
,p_display_sequence=>80
,p_prompt=>'Link column'
,p_attribute_type=>'REGION SOURCE COLUMN'
,p_is_required=>false
,p_column_data_types=>'VARCHAR2'
,p_is_translatable=>false
,p_help_text=>'Where a card goes when clicked (f?p=..., https://...). Empty = not a link.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(91734900000010)
,p_plugin_id=>wwv_flow_api.id(91734900000001)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>9
,p_display_sequence=>90
,p_prompt=>'State column'
,p_attribute_type=>'REGION SOURCE COLUMN'
,p_is_required=>false
,p_column_data_types=>'VARCHAR2'
,p_is_translatable=>false
,p_help_text=>'good / warn / bad / info: the colour of the card''s top edge.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(91734900000011)
,p_plugin_id=>wwv_flow_api.id(91734900000001)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>10
,p_display_sequence=>100
,p_prompt=>'Show heading'
,p_attribute_type=>'CHECKBOX'
,p_is_required=>false
,p_default_value=>'Y'
,p_is_translatable=>false
,p_help_text=>'The region''s title over the cards, with a live dot.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(91734900000012)
,p_plugin_id=>wwv_flow_api.id(91734900000001)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>11
,p_display_sequence=>110
,p_prompt=>'Heading link'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_display_length=>40
,p_max_length=>400
,p_is_translatable=>false
,p_help_text=>'An address at the end of the heading (substitutions allowed: f?p=&APP_ID.:42:&SESSION.).'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(91734900000013)
,p_plugin_id=>wwv_flow_api.id(91734900000001)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>12
,p_display_sequence=>120
,p_prompt=>'Heading link text'
,p_attribute_type=>'TEXT'
,p_is_required=>false
,p_display_length=>30
,p_max_length=>80
,p_is_translatable=>false
,p_help_text=>'The words of that link.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(91734900000014)
,p_plugin_id=>wwv_flow_api.id(91734900000001)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>13
,p_display_sequence=>130
,p_prompt=>'Refresh every (seconds)'
,p_attribute_type=>'INTEGER'
,p_is_required=>true
,p_default_value=>'30'
,p_display_length=>5
,p_is_translatable=>false
,p_help_text=>'0 = only on a Refresh action.'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(91734900000015)
,p_plugin_id=>wwv_flow_api.id(91734900000001)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>14
,p_display_sequence=>140
,p_prompt=>'Look'
,p_attribute_type=>'SELECT LIST'
,p_is_required=>true
,p_default_value=>'DARK'
,p_is_translatable=>false
,p_lov_type=>'STATIC'
,p_help_text=>'Dark (a gradient, white text) or light.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(91734900000016)
,p_plugin_attribute_id=>wwv_flow_api.id(91734900000015)
,p_display_sequence=>10
,p_display_value=>'Dark'
,p_return_value=>'DARK'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(91734900000017)
,p_plugin_attribute_id=>wwv_flow_api.id(91734900000015)
,p_display_sequence=>20
,p_display_value=>'Light'
,p_return_value=>'LIGHT'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(91734900000018)
,p_plugin_id=>wwv_flow_api.id(91734900000001)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>15
,p_display_sequence=>150
,p_prompt=>'Layout'
,p_attribute_type=>'SELECT LIST'
,p_is_required=>true
,p_default_value=>'STRIP'
,p_is_translatable=>false
,p_lov_type=>'STATIC'
,p_help_text=>'One row that scrolls sideways, or rows that wrap.'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(91734900000019)
,p_plugin_attribute_id=>wwv_flow_api.id(91734900000018)
,p_display_sequence=>10
,p_display_value=>'Strip'
,p_return_value=>'STRIP'
);
wwv_flow_api.create_plugin_attr_value(
 p_id=>wwv_flow_api.id(91734900000020)
,p_plugin_attribute_id=>wwv_flow_api.id(91734900000018)
,p_display_sequence=>20
,p_display_value=>'Grid'
,p_return_value=>'GRID'
);
wwv_flow_api.create_plugin_attribute(
 p_id=>wwv_flow_api.id(91734900000021)
,p_plugin_id=>wwv_flow_api.id(91734900000001)
,p_attribute_scope=>'COMPONENT'
,p_attribute_sequence=>16
,p_display_sequence=>160
,p_prompt=>'Card width (pixels)'
,p_attribute_type=>'INTEGER'
,p_is_required=>true
,p_default_value=>'150'
,p_display_length=>5
,p_is_translatable=>false
,p_help_text=>''
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '2F2A2048616465722063617264732028726567696F6E20706C75672D696E293A2074686520726F7773206F662074686520726567696F6E27732053514C2071756572792061732063617264732E2041205265667265736820616374696F6E206F6E207468';
wwv_flow_api.g_varchar2_table(2) := '6520726567696F6E2C206F72207468650A20202074696D652073657420696E2069747320617474726962757465732C207265616473207468656D20616761696E2E204E6F2048544D4C2066726F6D207468652071756572792069732074616B656E206173';
wwv_flow_api.g_varchar2_table(3) := '2048544D4C2E202A2F0A77696E646F772E6864724361726473203D202866756E6374696F6E202829207B0A20202775736520737472696374273B0A202066756E6374696F6E20736166654C696E6B287529207B0A2020202075203D20537472696E672875';
wwv_flow_api.g_varchar2_table(4) := '207C7C202727292E7472696D28293B0A2020202072657475726E202F5E2868747470733F3A5C2F5C2F7C665C3F703D7C5C2F7C5C2E5C2F7C237C7777765F666C6F775C2E73686F77292F692E74657374287529203F2075203A2027273B0A20207D0A2020';
wwv_flow_api.g_varchar2_table(5) := '66756E6374696F6E20656C287461672C20636C732C207465787429207B0A202020207661722065203D20646F63756D656E742E637265617465456C656D656E7428746167293B0A2020202069662028636C7329207B20652E636C6173734E616D65203D20';
wwv_flow_api.g_varchar2_table(6) := '636C733B207D0A20202020696620287465787420213D206E756C6C202626207465787420213D3D20272729207B20652E74657874436F6E74656E74203D20746578743B207D0A2020202072657475726E20653B0A20207D0A202066756E6374696F6E2069';
wwv_flow_api.g_varchar2_table(7) := '6E697428726567696F6E49642C20616A61782C206974656D732C2068656164696E672C20686561644C696E6B2C2068656164546578742C2065766572792C2070686F746F50726F632C206E6F4461746129207B0A2020202076617220626F78203D20646F';
wwv_flow_api.g_varchar2_table(8) := '63756D656E742E676574456C656D656E744279496428726567696F6E4964202B20275F68647227293B0A202020206966202821626F7829207B2072657475726E3B207D0A202020207661722074696D6572203D206E756C6C2C2062757379203D2066616C';
wwv_flow_api.g_varchar2_table(9) := '73653B0A2020202066756E6374696F6E2070686F746F55726C28636F646529207B0A20202020202076617220617070203D20646F63756D656E742E676574456C656D656E7442794964282770466C6F77496427292C20736573203D20646F63756D656E74';
wwv_flow_api.g_varchar2_table(10) := '2E676574456C656D656E7442794964282770496E7374616E636527293B0A20202020202072657475726E20277777765F666C6F772E73686F773F705F666C6F775F69643D27202B2028617070203F206170702E76616C7565203A20272729202B20272670';
wwv_flow_api.g_varchar2_table(11) := '5F666C6F775F737465705F69643D3026705F696E7374616E63653D27202B2028736573203F207365732E76616C7565203A20272729202B0A20202020202020202726705F726571756573743D4150504C49434154494F4E5F50524F434553532533442720';
wwv_flow_api.g_varchar2_table(12) := '2B20656E636F6465555249436F6D706F6E656E742870686F746F50726F63207C7C20274844525F50484F544F2729202B2027267830313D27202B20656E636F6465555249436F6D706F6E656E7428636F6465293B0A202020207D0A2020202066756E6374';
wwv_flow_api.g_varchar2_table(13) := '696F6E2063617264287229207B0A202020202020766172206C696E6B203D20736166654C696E6B28722E6C696E6B292C2063203D20656C286C696E6B203F20276127203A2027646976272C20276864722D6361726427202B2028722E7374617465203F20';
wwv_flow_api.g_varchar2_table(14) := '27206864722D636172642D27202B20722E73746174652E7265706C616365282F5B5E612D7A5D2F672C20272729203A20272729293B0A202020202020696620286C696E6B29207B20632E68726566203D206C696E6B3B207D0A2020202020207661722073';
wwv_flow_api.g_varchar2_table(15) := '7263203D20722E696D67203F20736166654C696E6B28722E696D6729203A2028722E70686F746F203F2070686F746F55726C28722E70686F746F29203A202727293B0A2020202020206966202873726329207B0A2020202020202020766172206176203D';
wwv_flow_api.g_varchar2_table(16) := '20656C28277370616E272C20276864722D636172642D617627292C20696D67203D20656C2827696D6727293B0A2020202020202020696D672E616C74203D2027273B20696D672E6C6F6164696E67203D20276C617A79273B20696D672E737263203D2073';
wwv_flow_api.g_varchar2_table(17) := '72633B0A2020202020202020696D672E6F6E6572726F72203D2066756E6374696F6E202829207B20696D672E7374796C652E7669736962696C697479203D202768696464656E273B207D3B0A202020202020202061762E617070656E644368696C642869';
wwv_flow_api.g_varchar2_table(18) := '6D67293B20632E617070656E644368696C64286176293B0A2020202020207D0A2020202020205B5B2762272C20722E7469746C655D2C205B27736D616C6C272C20722E7375625D2C205B277374726F6E67272C20722E76616C75655D2C205B277370616E';
wwv_flow_api.g_varchar2_table(19) := '272C20722E6D6574615D5D2E666F72456163682866756E6374696F6E20287029207B0A202020202020202069662028705B315D20213D206E756C6C20262620705B315D20213D3D20272729207B20632E617070656E644368696C6428656C28705B305D2C';
wwv_flow_api.g_varchar2_table(20) := '2027272C20705B315D29293B207D0A2020202020207D293B0A20202020202072657475726E20633B0A202020207D0A2020202066756E6374696F6E207061696E74286429207B0A202020202020626F782E696E6E657248544D4C203D2027273B0A202020';
wwv_flow_api.g_varchar2_table(21) := '2020206966202868656164696E67207C7C20686561644C696E6B29207B0A20202020202020207661722068656164203D20656C2827646976272C20276864722D63617264732D6865616427293B0A20202020202020206966202868656164696E6729207B';
wwv_flow_api.g_varchar2_table(22) := '207661722074203D20656C282762272C2027272C2068656164696E67293B20742E696E736572744265666F726528656C28276927292C20742E66697273744368696C64293B20686561642E617070656E644368696C642874293B207D0A20202020202020';
wwv_flow_api.g_varchar2_table(23) := '2076617220686C203D20736166654C696E6B28686561644C696E6B293B0A202020202020202069662028686C29207B207661722061203D20656C282761272C2027272C20286865616454657874207C7C20272729202B202720E280BA27293B20612E6872';
wwv_flow_api.g_varchar2_table(24) := '6566203D20686C3B20686561642E617070656E644368696C642861293B207D0A2020202020202020626F782E617070656E644368696C642868656164293B0A2020202020207D0A20202020202076617220726F77203D20656C2827646976272C20276864';
wwv_flow_api.g_varchar2_table(25) := '722D63617264732D726F7727293B0A20202020202069662028642E6661696C75726529207B20726F772E617070656E644368696C6428656C282770272C20276864722D63617264732D6E6F6E65272C20642E6661696C75726529293B207D0A2020202020';
wwv_flow_api.g_varchar2_table(26) := '20656C736520696620282128642E726F7773207C7C205B5D292E6C656E67746829207B20726F772E617070656E644368696C6428656C282770272C20276864722D63617264732D6E6F6E65272C206E6F44617461207C7C20272729293B207D0A20202020';
wwv_flow_api.g_varchar2_table(27) := '2020656C7365207B20642E726F77732E666F72456163682866756E6374696F6E20287229207B20726F772E617070656E644368696C642863617264287229293B207D293B207D0A202020202020626F782E617070656E644368696C6428726F77293B0A20';
wwv_flow_api.g_varchar2_table(28) := '2020207D0A2020202066756E6374696F6E206C6F61642829207B0A202020202020696620286275737929207B2072657475726E3B207D0A20202020202062757379203D20747275653B0A202020202020617065782E7365727665722E706C7567696E2861';
wwv_flow_api.g_varchar2_table(29) := '6A61782C207B20706167654974656D733A206974656D73207C7C20756E646566696E6564207D2C207B0A202020202020202064617461547970653A20276A736F6E272C0A2020202020202020737563636573733A2066756E6374696F6E20286429207B20';
wwv_flow_api.g_varchar2_table(30) := '62757379203D2066616C73653B207061696E742864207C7C207B7D293B207D2C0A20202020202020206572726F723A2066756E6374696F6E2028782C20732C206529207B2062757379203D2066616C73653B207061696E74287B206661696C7572653A20';
wwv_flow_api.g_varchar2_table(31) := '65207C7C2073207C7C20276572726F7227207D293B207D0A2020202020207D293B0A202020207D0A20202020617065782E6A517565727928272327202B20726567696F6E4964292E6F6E28276170657872656672657368272C206C6F6164293B0A202020';
wwv_flow_api.g_varchar2_table(32) := '206C6F616428293B0A20202020696620286576657279203E203029207B0A20202020202074696D6572203D20736574496E74657276616C2866756E6374696F6E202829207B2069662028646F63756D656E742E7669736962696C6974795374617465203D';
wwv_flow_api.g_varchar2_table(33) := '3D3D202776697369626C652720262620646F63756D656E742E626F64792E636F6E7461696E7328626F782929207B206C6F616428293B207D207D2C206576657279202A2031303030293B0A202020207D0A2020202072657475726E207B20726566726573';
wwv_flow_api.g_varchar2_table(34) := '683A206C6F61642C2073746F703A2066756E6374696F6E202829207B20636C656172496E74657276616C2874696D6572293B207D207D3B0A20207D0A202072657475726E207B20696E69743A20696E6974207D3B0A7D2928293B0A';
end;
/
prompt --application/shared_components/plugins/region_type/com_hader_cards/hader-cards.js
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(91734900000022)
,p_plugin_id=>wwv_flow_api.id(91734900000001)
,p_file_name=>'hader-cards.js'
,p_mime_type=>'application/javascript'
,p_file_charset=>'utf-8'
,p_file_content=>wwv_flow_api.varchar2_to_blob(wwv_flow_api.g_varchar2_table)
);
end;
/
begin
wwv_flow_api.g_varchar2_table := wwv_flow_api.empty_varchar2_table;
wwv_flow_api.g_varchar2_table(1) := '2E6864722D63617264737B626F726465722D7261646975733A313870783B70616464696E673A313470787D0A2E6864722D63617264732D6461726B7B6261636B67726F756E643A6C696E6561722D6772616469656E74283133356465672C233066326133';
wwv_flow_api.g_varchar2_table(2) := '632C23313235353466293B636F6C6F723A236666667D0A2E6864722D63617264732D6C696768747B6261636B67726F756E643A236666663B636F6C6F723A233066313732613B626F726465723A31707820736F6C696420236532653866307D0A2E686472';
wwv_flow_api.g_varchar2_table(3) := '2D63617264732D686561647B646973706C61793A666C65783B6A7573746966792D636F6E74656E743A73706163652D6265747765656E3B616C69676E2D6974656D733A63656E7465723B6D617267696E2D626F74746F6D3A313070787D0A2E6864722D63';
wwv_flow_api.g_varchar2_table(4) := '617264732D6865616420697B646973706C61793A696E6C696E652D626C6F636B3B77696474683A3970783B6865696768743A3970783B626F726465722D7261646975733A3530253B6261636B67726F756E643A233232633535653B6D617267696E2D696E';
wwv_flow_api.g_varchar2_table(5) := '6C696E652D656E643A3670787D0A2E6864722D63617264732D6865616420617B666F6E742D73697A653A313270783B746578742D6465636F726174696F6E3A6E6F6E657D0A2E6864722D63617264732D6461726B202E6864722D63617264732D68656164';
wwv_flow_api.g_varchar2_table(6) := '20617B636F6C6F723A233966653364367D0A2E6864722D63617264732D6C69676874202E6864722D63617264732D6865616420617B636F6C6F723A233065386638367D0A2E6864722D63617264732D726F777B646973706C61793A666C65783B6761703A';
wwv_flow_api.g_varchar2_table(7) := '313070783B70616464696E672D626F74746F6D3A3670787D0A2E6864722D63617264732D7374726970202E6864722D63617264732D726F777B6F766572666C6F772D783A6175746F7D0A2E6864722D63617264732D67726964202E6864722D6361726473';
wwv_flow_api.g_varchar2_table(8) := '2D726F777B666C65782D777261703A777261707D0A2E6864722D636172647B666C65783A30203020766172282D2D6864722D636172642D772C3135307078293B626F726465722D7261646975733A313470783B70616464696E673A313070783B74657874';
wwv_flow_api.g_varchar2_table(9) := '2D616C69676E3A63656E7465723B636F6C6F723A696E68657269743B746578742D6465636F726174696F6E3A6E6F6E653B626F726465722D746F703A33707820736F6C6964207472616E73706172656E747D0A2E6864722D63617264732D6461726B202E';
wwv_flow_api.g_varchar2_table(10) := '6864722D636172647B6261636B67726F756E643A72676261283235352C3235352C3235352C2E3038297D0A2E6864722D63617264732D6C69676874202E6864722D636172647B6261636B67726F756E643A236638666166633B626F726465723A31707820';
wwv_flow_api.g_varchar2_table(11) := '736F6C696420236532653866307D0A612E6864722D636172643A686F7665727B66696C7465723A6272696768746E65737328312E31297D0A2E6864722D636172642D676F6F647B626F726465722D746F702D636F6C6F723A233232633535657D2E686472';
wwv_flow_api.g_varchar2_table(12) := '2D636172642D7761726E7B626F726465722D746F702D636F6C6F723A236635396530627D2E6864722D636172642D6261647B626F726465722D746F702D636F6C6F723A236566343434347D2E6864722D636172642D696E666F7B626F726465722D746F70';
wwv_flow_api.g_varchar2_table(13) := '2D636F6C6F723A233338626466387D0A2E6864722D636172642D61767B646973706C61793A626C6F636B3B77696474683A343870783B6865696768743A343870783B6D617267696E3A30206175746F203670783B626F726465722D7261646975733A3530';
wwv_flow_api.g_varchar2_table(14) := '253B6F766572666C6F773A68696464656E3B6261636B67726F756E643A72676261283132372C3132372C3132372C2E32297D0A2E6864722D636172642D617620696D677B77696474683A313030253B6865696768743A313030253B6F626A6563742D6669';
wwv_flow_api.g_varchar2_table(15) := '743A636F7665727D0A2E6864722D6361726420627B646973706C61793A626C6F636B3B666F6E742D73697A653A313370783B6C696E652D6865696768743A312E337D0A2E6864722D6361726420736D616C6C7B646973706C61793A626C6F636B3B6F7061';
wwv_flow_api.g_varchar2_table(16) := '636974793A2E373B666F6E742D73697A653A313170787D0A2E6864722D63617264207374726F6E677B646973706C61793A626C6F636B3B666F6E742D73697A653A323070783B6D617267696E3A34707820307D0A2E6864722D63617264207370616E7B66';
wwv_flow_api.g_varchar2_table(17) := '6F6E742D73697A653A313170783B6F7061636974793A2E37357D0A2E6864722D63617264732D6E6F6E657B6F7061636974793A2E37353B6D617267696E3A3670787D0A';
end;
/
prompt --application/shared_components/plugins/region_type/com_hader_cards/hader-cards.css
begin
wwv_flow_api.create_plugin_file(
 p_id=>wwv_flow_api.id(91734900000023)
,p_plugin_id=>wwv_flow_api.id(91734900000001)
,p_file_name=>'hader-cards.css'
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
