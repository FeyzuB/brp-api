create or replace package brp_leef_bewoning is
  type t_periode_rec is record (
    datum_van varchar2(10),
    datum_tot varchar2(10)
  );
  type t_naam_rec is record (
    volledige_naam varchar2(4000)
  );
  type t_geboorte_datum_rec is record (
    datum varchar2(10)
  );
  type t_geboorte_rec is record (
    datum t_geboorte_datum_rec
  );
  type t_bewoner_rec is record (
    burgerservicenummer varchar2(20),
    geheimhouding_persoonsgegevens number(1),
    naam t_naam_rec,
    geboorte t_geboorte_rec,
    raw_json clob
  );
  type t_bewoner_tab is table of t_bewoner_rec;
  type t_bewoning_rec is record (
    adresseerbaar_object_identificatie varchar2(50),
    periode t_periode_rec,
    bewoners t_bewoner_tab,
    mogelijke_bewoners t_bewoner_tab,
    raw_json clob
  );
  type t_bewoning_tab is table of t_bewoning_rec;
  type t_bewoning_response_rec is record (
    bewoningen t_bewoning_tab,
    raw_json clob
  );

  procedure lees_bewoningen(
    i_adresseerbaar_object_identificatie in varchar2 default null,
    i_datum_van in varchar2 default null,
    i_datum_tot in varchar2 default null,
    i_burgerservicenummer in varchar2 default null,
    o_status_code out number,
    o_response out t_bewoning_response_rec,
    o_error out clob
  );
end brp_leef_bewoning;
/
