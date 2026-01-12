create or replace package body brp_api_personen is
  gc_package constant varchar2(100) := 'brp_api_personen.';
  gc_log_einde constant varchar2(30) := 'EINDE';

  gc_path constant varchar2(200) := '/personen'; -- Endpoint for Personen

  e_standard_exception exception;

  procedure zoek_personen(
    i_request_json in clob,
    o_status_code out number,
    o_response_body out clob,
    o_error out clob
  ) is
    lv_scope logger_logs.scope%type := gc_package || 'zoek_personen';
    lv_params logger.tab_param;
    lv_url varchar2(4000);
  begin
    o_error := null;
    if g_api_base_url is null then
      o_error := 'Fout: API basis URL ontbreekt.';
      raise e_standard_exception;
    end if;
    if i_request_json is null then
      o_error := 'Fout: Request body ontbreekt.';
      raise e_standard_exception;
    end if;

    lv_url := g_api_base_url || gc_path;
    apex_web_service.g_request_headers.delete;
    apex_web_service.g_request_headers(1).name := 'Content-Type';
    apex_web_service.g_request_headers(1).value := 'application/json; charset=utf-8';
    apex_web_service.g_request_headers(2).name := 'Accept';
    apex_web_service.g_request_headers(2).value := 'application/json';

    o_response_body := apex_web_service.make_rest_request(
      p_url => lv_url,
      p_http_method => 'POST',
      p_body => i_request_json
    );
    o_status_code := apex_web_service.g_status_code;

    logger.append_param(lv_params, 'o_status_code', to_char(o_status_code));
    logger.append_param(lv_params, 'o_response_body', dbms_lob.substr(o_response_body, 4000, 1));
    logger.log(gc_log_einde, lv_scope, null, lv_params);
  exception
    when e_standard_exception then
      if o_error is null then
        o_error := 'Fout in ' || lv_scope || ': ' || sqlerrm;
      end if;
      logger.log_error(o_error, lv_scope, null, lv_params);
      debug_output('o_error: ' || o_error);
    when others then
      if o_error is null then
        o_error := 'Fout in ' || lv_scope || ': ' || sqlerrm;
      end if;
      logger.log_error(o_error, lv_scope, null, lv_params);
      debug_output('o_error: ' || o_error);
  end zoek_personen;

end brp_api_personen;
/
