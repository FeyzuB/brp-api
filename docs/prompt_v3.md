You are a senior Oracle PL/SQL architect and API integration engineer.

Context:
- Platform: Oracle Database 19c + Oracle APEX 24.2.8
- We integrate with the BRP API via a proxy server (proxy handles certificates/TLS). Do NOT implement wallet/certificate handling.
- Separation of concerns is strict:
  1) API transport packages: only HTTP request/response handling. No business logic. No JSON parsing into domain objects.
  2) Service packages: business logic + JSON parsing/mapping into PL/SQL record/table types. Must include clear extension sections for custom logic.

Packages to create:

API transport packages (HTTP only; return raw responses):
1) brp_api_personen
2) brp_api_bewoning
3) brp_api_verblijfplaatshistorie

Service packages (business + parsing):
1) brp_leef_personen
2) brp_leef_bewoning
3) brp_leef_verblijfplaatshistorie

HTTP client library (mandatory):
- Use APEX_WEB_SERVICE only for all outbound HTTP calls (Oracle APEX 24.2.8).
- Do NOT use UTL_HTTP anywhere.
- Capture and return HTTP status code using APEX_WEB_SERVICE.g_status_code.
- Transport layer must return raw response body as CLOB and must not parse/interpret it.

HTTP semantics (BRP-specific):
- All BRP API endpoints use HTTP POST.
- Despite POST, all calls are read-only (GET semantics) for privacy/AVG reasons.
- Procedure names must reflect read-only intent (e.g. get_*, zoek_*, lees_*).
- Do not put any PII in the URL query string; send identifying/search inputs only in the POST JSON body.

Global base URL requirement:
- Each API transport package must have a single global variable/constant for the base URL, e.g. g_api_base_url, so I can switch it to point to the proxy server.
- Construct endpoint URLs by appending paths to g_api_base_url.

Endpoint scope (based on the provided YAML files):
- Implement exactly ONE operation per domain:
  - Personen: POST /personen
  - Bewoning: POST /bewoningen
  - Verblijfplaatshistorie: POST /verblijfplaatshistorie
- Each API transport package must have one public procedure to call its endpoint.
- Each service package must have one public procedure that calls the API procedure and parses the JSON response into typed PL/SQL records/tables.

Procedure-only rule:
- Implement operations as PROCEDURES (not functions), so every operation supports o_error OUT CLOB and the mandatory logging/exception template.

Output contract for API transport procedures:
- Each API procedure must accept:
  - i_request_json CLOB (complete JSON body, already prepared by service layer)
- Each API procedure must return:
  - o_status_code OUT NUMBER
  - o_response_body OUT CLOB
  - o_error OUT CLOB
- API layer does NOT parse JSON.

Service request construction (mandatory):
- Service procedures must NOT accept i_request_json.
- Service procedures must accept typed IN parameters that correspond to JSON body keys (e.g., identificaties, datumVan/datumTot filters).
- Service procedures must construct the JSON request body internally using JSON_OBJECT_T/JSON_ARRAY_T and serialize it to CLOB.
- API transport procedures remain unchanged: they accept i_request_json CLOB and return o_status_code + o_response_body CLOB + o_error.

Service layer responsibilities:
- Service procedure accepts typed IN parameters corresponding to JSON body keys, constructs the JSON request body, calls the API procedure, then parses the response JSON.
- Every service procedure must include a clearly marked extension section:
  -- CUSTOM LOGIC START
  -- CUSTOM LOGIC END

Type modeling rules (mandatory, no placeholders):
- Do NOT generate domain record types like (result_type, raw_json) only.
- Define nested PL/SQL RECORD and TABLE types in each SERVICE PACKAGE SPEC that mirror the response hierarchy of the YAML examples.
- Use VARCHAR2(10) for ISO dates 'YYYY-MM-DD'.
- Oracle has no SQL BOOLEAN here; represent booleans as NUMBER(1) (0/1).
- Keep raw_json CLOB as a safety net at the top-level response record (and optionally per item) so unmodeled fields are not lost.

Service procedure input parameters (mandatory):
- brp_leef_bewoning.lees_bewoningen must accept:
  - i_adresseerbaar_object_identificatie IN VARCHAR2 DEFAULT NULL
  - i_datum_van IN VARCHAR2 DEFAULT NULL
  - i_datum_tot IN VARCHAR2 DEFAULT NULL
  - i_burgerservicenummer IN VARCHAR2 DEFAULT NULL

- brp_leef_personen.lees_personen must accept:
  - i_burgerservicenummer IN VARCHAR2 DEFAULT NULL
  - i_geboortedatum IN VARCHAR2 DEFAULT NULL
  - i_naam_zoekterm IN VARCHAR2 DEFAULT NULL

- brp_leef_verblijfplaatshistorie.lees_verblijfplaatshistorie must accept:
  - i_burgerservicenummer IN VARCHAR2
  - i_datum_van IN VARCHAR2 DEFAULT NULL
  - i_datum_tot IN VARCHAR2 DEFAULT NULL


Type requirements per domain:

A) Bewoning (response contains bewoningen array; each has periode + bewoners arrays)
- In brp_leef_bewoning spec define:
  - t_periode_rec (datum_van, datum_tot)
  - t_naam_rec (volledige_naam)
  - t_geboorte_datum_rec (datum)
  - t_geboorte_rec (datum t_geboorte_datum_rec)
  - t_bewoner_rec:
      burgerservicenummer VARCHAR2(20)
      geheimhouding_persoonsgegevens NUMBER(1)
      naam t_naam_rec (optional; allow NULL fields)
      geboorte t_geboorte_rec (optional; allow NULL fields)
      raw_json CLOB (optional but allowed)
    t_bewoner_tab = table of t_bewoner_rec
  - t_bewoning_rec:
      adresseerbaar_object_identificatie VARCHAR2(50)
      periode t_periode_rec
      bewoners t_bewoner_tab
      mogelijke_bewoners t_bewoner_tab
      raw_json CLOB
    t_bewoning_tab = table of t_bewoning_rec
  - t_bewoning_response_rec:
      bewoningen t_bewoning_tab
      raw_json CLOB

B) Personen (response contains personen array of persoon objects; model a useful subset + raw_json)
- In brp_leef_personen spec define:
  - t_naam_rec (volledige_naam)
  - t_geboorte_datum_rec (datum)
  - t_geboorte_rec (datum t_geboorte_datum_rec)
  - t_persoon_rec with at least:
      burgerservicenummer VARCHAR2(20)
      geheimhouding_persoonsgegevens NUMBER(1)
      naam t_naam_rec
      geboorte t_geboorte_rec
      raw_json CLOB
    t_persoon_tab = table of t_persoon_rec
  - t_personen_response_rec:
      personen t_persoon_tab
      raw_json CLOB
- Parsing: if response contains additional fields (like type/discriminator), store them in raw_json and/or ignore safely without failing.

C) Verblijfplaatshistorie (response contains verblijfplaatsen array; polymorphic “voorkomen” types)
- In brp_leef_verblijfplaatshistorie spec define:
  - t_verblijfplaats_voorkomen_rec with at least:
      type VARCHAR2(50)
      datum_van VARCHAR2(10)
      datum_tot VARCHAR2(10)
      adresseerbaar_object_identificatie VARCHAR2(50) (nullable)
      nummeraanduiding_identificatie VARCHAR2(50) (nullable)
      raw_json CLOB
    t_verblijfplaats_voorkomen_tab = table of t_verblijfplaats_voorkomen_rec
  - t_verblijfplaatshistorie_response_rec:
      verblijfplaatsen t_verblijfplaats_voorkomen_tab
      raw_json CLOB
- Parsing: for each item in verblijfplaatsen, always set .type. For known keys (datumVan/datumTot/adresseerbaarObjectIdentificatie/nummeraanduidingIdentificatie) map them when present; otherwise keep raw_json.

Implementation details:
- Initialize nested TABLE types before extending/assigning.
- Never commit/rollback in these packages.
- Do not assume internal database model structures; keep mapping out of scope. Provide TODO blocks where I can add internal mapping.

Mandatory coding standards:
- All procedures must follow the JSON template rules below exactly.
- The exception handler bodies for WHEN e_standard_exception and WHEN OTHERS must be identical (same statements in same order), except for the WHEN clause.

The following JSON defines mandatory coding standards.
These rules are authoritative and must be followed exactly.

{
  "standard": "PLSQL_PROCEDURE_TEMPLATE_V2",
  "applies_to": ["procedure"],
  "naming": {
    "local_variable_prefix": "lv_",
    "in_param_prefix": "i_",
    "out_param_prefix": "o_",
    "exception_prefix": "e_",
    "package_constant_for_scope_prefix": "gc_package"
  },
  "required_signature": {
    "must_include_out_param": {
      "name": "o_error",
      "datatype": "CLOB",
      "mode": "OUT",
      "rule": "Every procedure must have an OUT parameter o_error CLOB."
    }
  },
  "required_declare_block": {
    "nodes": [
      {
        "type": "VarDecl",
        "name": "lv_scope",
        "datatype": "logger_logs.scope%type",
        "default_expression": "gc_package || '[PROCEDURE_NAME]'",
        "notes": [
          "Replace [PROCEDURE_NAME] with the actual procedure name (no brackets in final code).",
          "Example: lv_scope := gc_package || 'get_resultaten';"
        ]
      },
      {
        "type": "VarDecl",
        "name": "lv_params",
        "datatype": "logger.tab_param"
      }
    ]
  },
  "exceptions": {
    "required_exception_symbol": {
      "name": "e_standard_exception",
      "type": "ExceptionDecl",
      "scope": "procedure_or_package",
      "rule": "A standard exception must exist and be used for handled errors."
    },
    "handled_error_pattern": {
      "nodes": [
        {
          "type": "Assign",
          "target": "o_error",
          "expression_template": "'Fout: ' || <DUTCH_MESSAGE>"
        },
        {
          "type": "Raise",
          "exception": "e_standard_exception"
        }
      ],
      "notes": [
        "If code handles an error intentionally, set o_error in Dutch and raise e_standard_exception."
      ]
    },
    "required_exception_handlers": [
      {
        "type": "ExceptionHandler",
        "when": "e_standard_exception",
        "body_nodes": [
          {
            "type": "If",
            "condition": "o_error is null",
            "then_nodes": [
              {
                "type": "Assign",
                "target": "o_error",
                "expression": "'Fout in ' || lv_scope || ': ' || sqlerrm"
              }
            ]
          },
          {
            "type": "Call",
            "callee": "logger.log_error",
            "args": ["o_error", "lv_scope", "null", "lv_params"]
          },
          {
            "type": "Call",
            "callee": "debug_output",
            "args": ["'o_error: ' || o_error"]
          }
        ],
        "notes": [
          "Handled errors must route through e_standard_exception and be logged in this handler."
        ]
      },
      {
        "type": "ExceptionHandler",
        "when": "OTHERS",
        "body_nodes": [
          {
            "type": "If",
            "condition": "o_error is null",
            "then_nodes": [
              {
                "type": "Assign",
                "target": "o_error",
                "expression": "'Fout in ' || lv_scope || ': ' || sqlerrm"
              }
            ]
          },
          {
            "type": "Call",
            "callee": "logger.log_error",
            "args": ["o_error", "lv_scope", "null", "lv_params"]
          },
          {
            "type": "Call",
            "callee": "debug_output",
            "args": ["'o_error: ' || o_error"]
          }
        ],
        "notes": ["Unexpected errors must be logged in this handler."]
      }
    ]
  },
  "required_end_of_procedure": {
    "nodes": [
      {
        "type": "Call",
        "callee": "logger.log",
        "args": ["gc_log_einde", "lv_scope", "null", "lv_params"],
        "constraints": [
          "Must be the last executable statement in the procedure.",
          "Before this call, ensure lv_params contains all OUT parameters except o_error."
        ]
      }
    ]
  },
  "logging": {
    "scope_rule": "lv_scope must be gc_package || '<procedure_name>' in final code.",
    "out_param_logging_rule": "At end: log all OUT parameters except o_error into lv_params, then call logger.log(gc_log_einde, lv_scope, null, lv_params) as last line."
  }
}


Output:
- Provide package specs and package bodies for all six packages.
- Compile-ready, with placeholder comments only where unavoidable (e.g., headers list, endpoint path constants).
- Keep code clean and consistent.
