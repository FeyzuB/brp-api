create or replace package body brp_leef_personen is
  gc_package constant varchar2(100) := 'brp_leef_personen.';
  gc_log_einde constant varchar2(30) := 'EINDE';

  e_standard_exception exception;

  procedure lees_personen(
    i_burgerservicenummer in varchar2 default null,
    i_geboortedatum in varchar2 default null,
    i_naam_zoekterm in varchar2 default null,
    o_status_code out number,
    o_response out t_personen_response_rec,
    o_error out clob
  ) is
    lv_scope logger_logs.scope%type := gc_package || 'lees_personen';
    lv_params logger.tab_param;
    lv_request_obj json_object_t;
    lv_response_body clob;
    lv_json_obj json_object_t;
    lv_json_arr json_array_t;
    lv_elem json_element_t;
    lv_item_obj json_object_t;
    lv_name_obj json_object_t;
    lv_birth_obj json_object_t;
    lv_birth_date_obj json_object_t;
    lv_persoon t_persoon_rec;

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
    o_response.personen := t_persoon_tab();
    o_response.raw_json := null;
    lv_response_body := null;

    if i_burgerservicenummer is null and i_geboortedatum is null and i_naam_zoekterm is null then
      o_error := 'Fout: Geen zoekparameters opgegeven.';
      raise e_standard_exception;
    end if;

    lv_request_obj := json_object_t();
    if i_burgerservicenummer is not null then
      lv_request_obj.put('burgerservicenummer', i_burgerservicenummer);
      lv_request_obj.put('type', 'RaadpleegMetBurgerservicenummer');
    end if;
    if i_geboortedatum is not null then
      lv_request_obj.put('geboortedatum', i_geboortedatum);
      if not lv_request_obj.has('type') then
        lv_request_obj.put('type', 'ZoekMetGeslachtsnaamEnGeboortedatum');
      end if;
    end if;
    if i_naam_zoekterm is not null then
      lv_request_obj.put('geslachtsnaam', i_naam_zoekterm);
      if not lv_request_obj.has('type') then
        lv_request_obj.put('type', 'ZoekMetGeslachtsnaamEnGeboortedatum');
      end if;
    end if;

    brp_api_personen.zoek_personen(
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
        if lv_json_obj.has('personen') then
          lv_json_arr := lv_json_obj.get_array('personen');
          if lv_json_arr is not null then
            for lv_idx in 0 .. lv_json_arr.get_size - 1 loop
              lv_elem := lv_json_arr.get(lv_idx);
              lv_persoon.burgerservicenummer := null;
              lv_persoon.geheimhouding_persoonsgegevens := null;
              lv_persoon.naam.volledige_naam := null;
              lv_persoon.geboorte.datum.datum := null;
              lv_persoon.raw_json := null;

              if lv_elem.is_object then
                lv_item_obj := treat(lv_elem as json_object_t);
                if lv_item_obj.has('burgerservicenummer') then
                  lv_persoon.burgerservicenummer := lv_item_obj.get_string('burgerservicenummer');
                end if;
                if lv_item_obj.has('geheimhoudingPersoonsgegevens') then
                  lv_persoon.geheimhouding_persoonsgegevens := bool_to_number(lv_item_obj.get_boolean('geheimhoudingPersoonsgegevens'));
                end if;
                if lv_item_obj.has('naam') then
                  lv_name_obj := lv_item_obj.get_object('naam');
                  if lv_name_obj is not null and lv_name_obj.has('volledigeNaam') then
                    lv_persoon.naam.volledige_naam := lv_name_obj.get_string('volledigeNaam');
                  end if;
                end if;
                if lv_item_obj.has('geboorte') then
                  lv_birth_obj := lv_item_obj.get_object('geboorte');
                  if lv_birth_obj is not null and lv_birth_obj.has('datum') then
                    lv_birth_date_obj := lv_birth_obj.get_object('datum');
                    if lv_birth_date_obj is not null and lv_birth_date_obj.has('datum') then
                      lv_persoon.geboorte.datum.datum := lv_birth_date_obj.get_string('datum');
                    end if;
                  end if;
                end if;
                lv_persoon.raw_json := lv_item_obj.to_clob;
              else
                lv_persoon.raw_json := lv_elem.to_clob;
              end if;

              o_response.personen.extend;
              o_response.personen(o_response.personen.count) := lv_persoon;
            end loop;
          end if;
        end if;
      end if;
    end if;

    -- CUSTOM LOGIC START
    -- CUSTOM LOGIC END

    logger.append_param(lv_params, 'o_status_code', to_char(o_status_code));
    logger.append_param(lv_params, 'o_response.raw_json', dbms_lob.substr(o_response.raw_json, 4000, 1));
    logger.append_param(lv_params, 'o_response.personen', to_char(o_response.personen.count));
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
  end lees_personen;

end brp_leef_personen;
/
