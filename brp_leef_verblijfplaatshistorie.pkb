create or replace package body brp_leef_verblijfplaatshistorie is
  gc_package constant varchar2(100) := 'brp_leef_verblijfplaatshistorie.';
  gc_log_einde constant varchar2(30) := 'EINDE';

  e_standard_exception exception;

  procedure lees_verblijfplaatshistorie(
    i_burgerservicenummer in varchar2,
    i_datum_van in varchar2 default null,
    i_datum_tot in varchar2 default null,
    o_status_code out number,
    o_response out t_verblijfplaatshistorie_response_rec,
    o_error out clob
  ) is
    lv_scope logger_logs.scope%type := gc_package || 'lees_verblijfplaatshistorie';
    lv_params logger.tab_param;
    lv_request_obj json_object_t;
    lv_response_body clob;
    lv_json_obj json_object_t;
    lv_json_arr json_array_t;
    lv_elem json_element_t;
    lv_item_obj json_object_t;
    lv_item t_verblijfplaats_voorkomen_rec;
  begin
    o_error := null;
    o_status_code := null;
    o_response.verblijfplaatsen := t_verblijfplaats_voorkomen_tab();
    o_response.raw_json := null;
    lv_response_body := null;

    if i_burgerservicenummer is null then
      o_error := 'Fout: Burgerservicenummer ontbreekt.';
      raise e_standard_exception;
    end if;

    if i_datum_van is null and i_datum_tot is null then
      o_error := 'Fout: Peildatum of periode ontbreekt.';
      raise e_standard_exception;
    end if;

    lv_request_obj := json_object_t();
    lv_request_obj.put('burgerservicenummer', i_burgerservicenummer);
    if i_datum_van is not null and i_datum_tot is not null then
      lv_request_obj.put('type', 'RaadpleegMetPeriode');
      lv_request_obj.put('datumVan', i_datum_van);
      lv_request_obj.put('datumTot', i_datum_tot);
    else
      lv_request_obj.put('type', 'RaadpleegMetPeildatum');
      lv_request_obj.put('peildatum', nvl(i_datum_van, i_datum_tot));
    end if;

    brp_api_verblijfplaatshistorie.lees_verblijfplaatshistorie(
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
        if lv_json_obj.has('verblijfplaatsen') then
          lv_json_arr := lv_json_obj.get_array('verblijfplaatsen');
          if lv_json_arr is not null then
            for lv_idx in 0 .. lv_json_arr.get_size - 1 loop
              lv_elem := lv_json_arr.get(lv_idx);
              lv_item.type := null;
              lv_item.datum_van := null;
              lv_item.datum_tot := null;
              lv_item.adresseerbaar_object_identificatie := null;
              lv_item.nummeraanduiding_identificatie := null;
              lv_item.raw_json := null;

              if lv_elem.is_object then
                lv_item_obj := treat(lv_elem as json_object_t);
                if lv_item_obj.has('type') then
                  lv_item.type := lv_item_obj.get_string('type');
                end if;
                if lv_item_obj.has('datumVan') then
                  lv_item.datum_van := lv_item_obj.get_string('datumVan');
                end if;
                if lv_item_obj.has('datumTot') then
                  lv_item.datum_tot := lv_item_obj.get_string('datumTot');
                end if;
                if lv_item_obj.has('adresseerbaarObjectIdentificatie') then
                  lv_item.adresseerbaar_object_identificatie := lv_item_obj.get_string('adresseerbaarObjectIdentificatie');
                end if;
                if lv_item_obj.has('nummeraanduidingIdentificatie') then
                  lv_item.nummeraanduiding_identificatie := lv_item_obj.get_string('nummeraanduidingIdentificatie');
                end if;
                lv_item.raw_json := lv_item_obj.to_clob;
              else
                lv_item.raw_json := lv_elem.to_clob;
              end if;

              o_response.verblijfplaatsen.extend;
              o_response.verblijfplaatsen(o_response.verblijfplaatsen.count) := lv_item;
            end loop;
          end if;
        end if;
      end if;
    end if;

    -- CUSTOM LOGIC START
    -- CUSTOM LOGIC END

    logger.append_param(lv_params, 'o_status_code', to_char(o_status_code));
    logger.append_param(lv_params, 'o_response.raw_json', dbms_lob.substr(o_response.raw_json, 4000, 1));
    logger.append_param(lv_params, 'o_response.verblijfplaatsen', to_char(o_response.verblijfplaatsen.count));
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
  end lees_verblijfplaatshistorie;

end brp_leef_verblijfplaatshistorie;
/
