create or replace package body brp_leef_bewoning is
  gc_package constant varchar2(100) := 'brp_leef_bewoning.';
  gc_log_einde constant varchar2(30) := 'EINDE';

  e_standard_exception exception;

  procedure lees_bewoningen(
    i_adresseerbaar_object_identificatie in varchar2 default null,
    i_datum_van in varchar2 default null,
    i_datum_tot in varchar2 default null,
    i_burgerservicenummer in varchar2 default null,
    o_status_code out number,
    o_response out t_bewoning_response_rec,
    o_error out clob
  ) is
    lv_scope logger_logs.scope%type := gc_package || 'lees_bewoningen';
    lv_params logger.tab_param;
    lv_request_obj json_object_t;
    lv_response_body clob;
    lv_json_obj json_object_t;
    lv_json_arr json_array_t;
    lv_elem json_element_t;
    lv_item_obj json_object_t;
    lv_periode_obj json_object_t;
    lv_bewoners_arr json_array_t;
    lv_mogelijke_arr json_array_t;
    lv_bewoner_elem json_element_t;
    lv_bewoner_obj json_object_t;
    lv_naam_obj json_object_t;
    lv_geboorte_obj json_object_t;
    lv_geboorte_datum_obj json_object_t;
    lv_bewoning t_bewoning_rec;
    lv_bewoner t_bewoner_rec;

    function bool_to_number(i_value boolean) return number is
    begin
      if i_value then
        return 1;
      end if;
      return 0;
    end bool_to_number;
  begin
    o_error := null;
    o_status_code := null;
    o_response.bewoningen := t_bewoning_tab();
    o_response.raw_json := null;
    lv_response_body := null;

    if i_adresseerbaar_object_identificatie is null and i_burgerservicenummer is null then
      o_error := 'Fout: Identificatie ontbreekt.';
      raise e_standard_exception;
    end if;

    if i_datum_van is null and i_datum_tot is null then
      o_error := 'Fout: Peildatum of periode ontbreekt.';
      raise e_standard_exception;
    end if;

    lv_request_obj := json_object_t();
    if i_adresseerbaar_object_identificatie is not null then
      lv_request_obj.put('adresseerbaarObjectIdentificatie', i_adresseerbaar_object_identificatie);
    end if;
    if i_burgerservicenummer is not null then
      lv_request_obj.put('burgerservicenummer', i_burgerservicenummer);
    end if;

    if i_datum_van is not null and i_datum_tot is not null then
      lv_request_obj.put('type', 'BewoningMetPeriode');
      lv_request_obj.put('datumVan', i_datum_van);
      lv_request_obj.put('datumTot', i_datum_tot);
    else
      lv_request_obj.put('type', 'BewoningMetPeildatum');
      lv_request_obj.put('peildatum', nvl(i_datum_van, i_datum_tot));
    end if;

    brp_api_bewoning.lees_bewoning(
      i_request_json => lv_request_obj.to_clob,
      o_status_code => o_status_code,
      o_response_body => lv_response_body,
      o_error => o_error
    );

    if o_error is not null then
      raise e_standard_exception;
    end if;

    o_response.raw_json := lv_response_body;

    if o_status_code between 200 and 299 then
      if lv_response_body is not null then
        lv_json_obj := json_object_t.parse(lv_response_body);
        if lv_json_obj.has('bewoningen') then
          lv_json_arr := lv_json_obj.get_array('bewoningen');
          if lv_json_arr is not null then
            for lv_idx in 0 .. lv_json_arr.get_size - 1 loop
              lv_elem := lv_json_arr.get(lv_idx);
              lv_bewoning.adresseerbaar_object_identificatie := null;
              lv_bewoning.periode.datum_van := null;
              lv_bewoning.periode.datum_tot := null;
              lv_bewoning.bewoners := t_bewoner_tab();
              lv_bewoning.mogelijke_bewoners := t_bewoner_tab();
              lv_bewoning.raw_json := null;

              if lv_elem.is_object then
                lv_item_obj := treat(lv_elem as json_object_t);
                if lv_item_obj.has('adresseerbaarObjectIdentificatie') then
                  lv_bewoning.adresseerbaar_object_identificatie := lv_item_obj.get_string('adresseerbaarObjectIdentificatie');
                end if;
                if lv_item_obj.has('periode') then
                  lv_periode_obj := lv_item_obj.get_object('periode');
                  if lv_periode_obj is not null then
                    if lv_periode_obj.has('datumVan') then
                      lv_bewoning.periode.datum_van := lv_periode_obj.get_string('datumVan');
                    end if;
                    if lv_periode_obj.has('datumTot') then
                      lv_bewoning.periode.datum_tot := lv_periode_obj.get_string('datumTot');
                    end if;
                  end if;
                end if;

                if lv_item_obj.has('bewoners') then
                  lv_bewoners_arr := lv_item_obj.get_array('bewoners');
                  if lv_bewoners_arr is not null then
                    for lv_b_idx in 0 .. lv_bewoners_arr.get_size - 1 loop
                      lv_bewoner_elem := lv_bewoners_arr.get(lv_b_idx);
                      lv_bewoner.burgerservicenummer := null;
                      lv_bewoner.geheimhouding_persoonsgegevens := null;
                      lv_bewoner.naam.volledige_naam := null;
                      lv_bewoner.geboorte.datum.datum := null;
                      lv_bewoner.raw_json := null;

                      if lv_bewoner_elem.is_object then
                        lv_bewoner_obj := treat(lv_bewoner_elem as json_object_t);
                        if lv_bewoner_obj.has('burgerservicenummer') then
                          lv_bewoner.burgerservicenummer := lv_bewoner_obj.get_string('burgerservicenummer');
                        end if;
                        if lv_bewoner_obj.has('geheimhoudingPersoonsgegevens') then
                          lv_bewoner.geheimhouding_persoonsgegevens := bool_to_number(lv_bewoner_obj.get_boolean('geheimhoudingPersoonsgegevens'));
                        end if;
                        if lv_bewoner_obj.has('naam') then
                          lv_naam_obj := lv_bewoner_obj.get_object('naam');
                          if lv_naam_obj is not null and lv_naam_obj.has('volledigeNaam') then
                            lv_bewoner.naam.volledige_naam := lv_naam_obj.get_string('volledigeNaam');
                          end if;
                        end if;
                        if lv_bewoner_obj.has('geboorte') then
                          lv_geboorte_obj := lv_bewoner_obj.get_object('geboorte');
                          if lv_geboorte_obj is not null and lv_geboorte_obj.has('datum') then
                            lv_geboorte_datum_obj := lv_geboorte_obj.get_object('datum');
                            if lv_geboorte_datum_obj is not null and lv_geboorte_datum_obj.has('datum') then
                              lv_bewoner.geboorte.datum.datum := lv_geboorte_datum_obj.get_string('datum');
                            end if;
                          end if;
                        end if;
                        lv_bewoner.raw_json := lv_bewoner_obj.to_clob;
                      else
                        lv_bewoner.raw_json := lv_bewoner_elem.to_clob;
                      end if;

                      lv_bewoning.bewoners.extend;
                      lv_bewoning.bewoners(lv_bewoning.bewoners.count) := lv_bewoner;
                    end loop;
                  end if;
                end if;

                if lv_item_obj.has('mogelijkeBewoners') then
                  lv_mogelijke_arr := lv_item_obj.get_array('mogelijkeBewoners');
                  if lv_mogelijke_arr is not null then
                    for lv_m_idx in 0 .. lv_mogelijke_arr.get_size - 1 loop
                      lv_bewoner_elem := lv_mogelijke_arr.get(lv_m_idx);
                      lv_bewoner.burgerservicenummer := null;
                      lv_bewoner.geheimhouding_persoonsgegevens := null;
                      lv_bewoner.naam.volledige_naam := null;
                      lv_bewoner.geboorte.datum.datum := null;
                      lv_bewoner.raw_json := null;

                      if lv_bewoner_elem.is_object then
                        lv_bewoner_obj := treat(lv_bewoner_elem as json_object_t);
                        if lv_bewoner_obj.has('burgerservicenummer') then
                          lv_bewoner.burgerservicenummer := lv_bewoner_obj.get_string('burgerservicenummer');
                        end if;
                        if lv_bewoner_obj.has('geheimhoudingPersoonsgegevens') then
                          lv_bewoner.geheimhouding_persoonsgegevens := bool_to_number(lv_bewoner_obj.get_boolean('geheimhoudingPersoonsgegevens'));
                        end if;
                        if lv_bewoner_obj.has('naam') then
                          lv_naam_obj := lv_bewoner_obj.get_object('naam');
                          if lv_naam_obj is not null and lv_naam_obj.has('volledigeNaam') then
                            lv_bewoner.naam.volledige_naam := lv_naam_obj.get_string('volledigeNaam');
                          end if;
                        end if;
                        if lv_bewoner_obj.has('geboorte') then
                          lv_geboorte_obj := lv_bewoner_obj.get_object('geboorte');
                          if lv_geboorte_obj is not null and lv_geboorte_obj.has('datum') then
                            lv_geboorte_datum_obj := lv_geboorte_obj.get_object('datum');
                            if lv_geboorte_datum_obj is not null and lv_geboorte_datum_obj.has('datum') then
                              lv_bewoner.geboorte.datum.datum := lv_geboorte_datum_obj.get_string('datum');
                            end if;
                          end if;
                        end if;
                        lv_bewoner.raw_json := lv_bewoner_obj.to_clob;
                      else
                        lv_bewoner.raw_json := lv_bewoner_elem.to_clob;
                      end if;

                      lv_bewoning.mogelijke_bewoners.extend;
                      lv_bewoning.mogelijke_bewoners(lv_bewoning.mogelijke_bewoners.count) := lv_bewoner;
                    end loop;
                  end if;
                end if;
                lv_bewoning.raw_json := lv_item_obj.to_clob;
              else
                lv_bewoning.raw_json := lv_elem.to_clob;
              end if;

              o_response.bewoningen.extend;
              o_response.bewoningen(o_response.bewoningen.count) := lv_bewoning;
            end loop;
          end if;
        end if;
      end if;
    end if;

    -- CUSTOM LOGIC START
    -- CUSTOM LOGIC END

    logger.append_param(lv_params, 'o_status_code', to_char(o_status_code));
    logger.append_param(lv_params, 'o_response.raw_json', dbms_lob.substr(o_response.raw_json, 4000, 1));
    logger.append_param(lv_params, 'o_response.bewoningen', to_char(o_response.bewoningen.count));
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
  end lees_bewoningen;

end brp_leef_bewoning;
/
