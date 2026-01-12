create or replace package brp_api_verblijfplaatshistorie is
  g_api_base_url varchar2(4000) := 'https://proxy.example.local/brp';

  procedure lees_verblijfplaatshistorie(
    i_request_json in clob,
    o_status_code out number,
    o_response_body out clob,
    o_error out clob
  );

end brp_api_verblijfplaatshistorie;
/
