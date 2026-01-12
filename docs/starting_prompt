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

Global base URL requirement:
- Each API transport package must have a single global variable/constant for the base URL, e.g. g_api_base_url, so I can switch it to point to the proxy server.
- Construct endpoint URLs by appending paths to g_api_base_url.

Endpoints:
- Implement “all three endpoints” for each of the three domains above. (If you need endpoint names/paths, create compile-ready stubs with placeholders like p_path and document where to fill the exact path.)
- Each endpoint in the API package should have a corresponding service method in the service package.

Design requirements:
- API package methods should:
  - accept inputs (request payload as CLOB and/or structured params that are converted into JSON)
  - build URL + headers
  - perform HTTP call using HTTP method POST only
  - return: status_code NUMBER, response_body CLOB (and optionally response_headers)
  - never interpret the body (no business logic, no JSON parsing)

HTTP client library (mandatory):
- Use APEX_WEB_SERVICE only for all outbound HTTP calls (Oracle APEX 24.2.8).
- Do NOT use UTL_HTTP anywhere.
- Capture and return HTTP status code using APEX_WEB_SERVICE.g_status_code (and if needed APEX_WEB_SERVICE.g_headers).
- Transport layer must return raw response body as CLOB and must not parse/interpret it.

HTTP semantics (BRP-specific):
- All BRP API endpoints use HTTP POST.
- Despite POST, all calls are read-only (GET semantics) for privacy/AVG reasons.
- Procedure names must reflect read-only intent (e.g. get_*, zoek_*, lees_*).
- Do not put any PII in the URL query string; send identifying/search inputs only in the POST JSON body.

- Service package methods should:
  - call the API package
  - parse JSON using Oracle 19c JSON types (JSON_OBJECT_T / JSON_ARRAY_T)
  - map into PL/SQL types (RECORD and TABLE types)
  - include a clearly marked section:
    -- CUSTOM LOGIC START
    -- CUSTOM LOGIC END
  - never include any of my internal database model details. Use neutral domain types only.

Types:
- In each service package SPEC define:
  - t_error_rec, t_error_tab
  - t_http_result_rec (status_code, response_body, request_id/correlation_id optional)
  - domain result types:
    - a minimal record/table type that can be expanded later
    - also include a field like raw_json CLOB so I can keep unmodeled JSON safely
- Keep helper parsing functions in the BODY.

Coding standards (must follow):
- Use consistent naming: IN params: i_*, OUT params: o_*, locals: lv_*, globals/constants: gc_* .
- No COMMIT/ROLLBACK inside these packages.
- Use e_standard_exception for handled errors; do not call raise_application_error unless explicitly required elsewhere.
- Be careful with CLOB handling and response reading.
- Implement endpoints as procedures, not functions.

Output:
- Provide package specs and package bodies for all six packages, compile-ready with placeholders where real endpoint paths/params must be filled.
- Include comments describing where to fill endpoint paths for Personen, Bewoning, and Verblijfplaatshistorie.
- Keep the code clean and consistent.

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
          "expression_template": "<DUTCH_MESSAGE>"
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
