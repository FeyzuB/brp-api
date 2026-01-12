create or replace package brp_leef_personen is
  type t_naam_rec is record (
    volledige_naam varchar2(4000)
  );
  type t_geboorte_datum_rec is record (
    datum varchar2(10)
  );
  type t_geboorte_rec is record (
    datum t_geboorte_datum_rec
  );
  type t_persoon_rec is record (
    burgerservicenummer varchar2(20),
    geheimhouding_persoonsgegevens number(1),
    naam t_naam_rec,
    geboorte t_geboorte_rec,
    raw_json clob
  );
  type t_persoon_tab is table of t_persoon_rec;
  type t_personen_response_rec is record (
    personen t_persoon_tab,
    raw_json clob
  );

  procedure lees_personen(
    i_burgerservicenummer in varchar2 default null,
    i_geboortedatum in varchar2 default null,
    i_naam_zoekterm in varchar2 default null,
    o_status_code out number,
    o_response out t_personen_response_rec,
    o_error out clob
  );
end brp_leef_personen;
/
