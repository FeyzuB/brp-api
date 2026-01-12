create or replace package brp_leef_verblijfplaatshistorie is
  type t_verblijfplaats_voorkomen_rec is record (
    type varchar2(50),
    datum_van varchar2(10),
    datum_tot varchar2(10),
    adresseerbaar_object_identificatie varchar2(50),
    nummeraanduiding_identificatie varchar2(50),
    raw_json clob
  );
  type t_verblijfplaats_voorkomen_tab is table of t_verblijfplaats_voorkomen_rec;
  type t_verblijfplaatshistorie_response_rec is record (
    verblijfplaatsen t_verblijfplaats_voorkomen_tab,
    raw_json clob
  );

  procedure lees_verblijfplaatshistorie(
    i_burgerservicenummer in varchar2,
    i_datum_van in varchar2 default null,
    i_datum_tot in varchar2 default null,
    o_status_code out number,
    o_response out t_verblijfplaatshistorie_response_rec,
    o_error out clob
  );
end brp_leef_verblijfplaatshistorie;
/
