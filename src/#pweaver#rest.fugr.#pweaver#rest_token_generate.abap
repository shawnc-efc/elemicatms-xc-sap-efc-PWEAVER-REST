FUNCTION /pweaver/rest_token_generate.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(CARRIERCONFIG) TYPE  /PWEAVER/CCONFIG OPTIONAL
*"     VALUE(PRODUCT) TYPE  /PWEAVER/PRODUCT OPTIONAL
*"     VALUE(SHIPURL) TYPE  /PWEAVER/SHIPURL OPTIONAL
*"     VALUE(IS_TOKEN) TYPE  /PWEAVER/TOKENS OPTIONAL
*"  EXPORTING
*"     VALUE(TOKENS) TYPE  /PWEAVER/TOKENS
*"     VALUE(ERROR_MESSAGE) TYPE  /PWEAVER/STRING
*"----------------------------------------------------------------------

  CONSTANTS: lc_pwmodule_rtg    TYPE /pweaver/pwmodule VALUE 'RTG',
             lc_pwmodule_ettrtg TYPE /pweaver/pwmodule VALUE 'ETTRTG',
             lc_pod             TYPE char5 VALUE 'POD',
             lc_podimage        TYPE char10 VALUE 'PODIMAGE',
             lc_rest            TYPE char5 VALUE 'REST',
             lc_api             TYPE char5 VALUE 'API',
             lc_fedex           TYPE char10 VALUE 'FEDEX'.

  DATA: lv_pwmodule TYPE /pweaver/pwmodule.
  IF carrierconfig IS INITIAL.
    RAISE carrierconfig_not_found.
  ENDIF.

  DATA: lt_shipurl TYPE TABLE OF /pweaver/shipurl,
        ls_shipurl TYPE /pweaver/shipurl.

  IF carrierconfig-carriertype = lc_fedex AND ( shipurl-pwmodule = lc_pod OR shipurl-pwmodule = lc_podimage ).
    lv_pwmodule = lc_pwmodule_ettrtg.
  ELSE.
    lv_pwmodule = lc_pwmodule_rtg.
  ENDIF.

  SELECT * FROM /pweaver/shipurl INTO TABLE lt_shipurl WHERE systemid = sy-sysid AND
                                                             pwmodule = lv_pwmodule.
  IF sy-subrc = 0.
    READ TABLE lt_shipurl INTO ls_shipurl WITH KEY plant = product-plant
                                             carriertype = carrierconfig-lifnr.
    IF sy-subrc <> 0.
      READ TABLE lt_shipurl INTO ls_shipurl WITH KEY plant = product-plant
                                               carriertype = carrierconfig-carrieridf.
      IF sy-subrc <> 0.
        READ TABLE lt_shipurl INTO ls_shipurl WITH KEY plant = product-plant
                                                 carriertype = carrierconfig-carriertype.
        IF sy-subrc <> 0.
          READ TABLE lt_shipurl INTO ls_shipurl WITH KEY carriertype = carrierconfig-lifnr.
          IF sy-subrc <> 0.
            READ TABLE lt_shipurl INTO ls_shipurl WITH KEY carriertype = carrierconfig-carrieridf.
            IF sy-subrc <> 0 .
              READ TABLE lt_shipurl INTO ls_shipurl WITH KEY carriertype = carrierconfig-carriertype.
            ENDIF.
          ENDIF.
        ENDIF.
      ENDIF.
    ENDIF.
  ELSE.
    RAISE shipurl_not_found.
  ENDIF.


  IF ls_shipurl IS INITIAL.
    RAISE shipurl_not_found.
  ELSE.

    IF ls_shipurl-communication = lc_api AND ls_shipurl-carriermethod = lc_rest.   " Means We are using RestAPI without SIG Communication {SAP Communication}
      PERFORM rtg_sap_rest USING carrierconfig ls_shipurl is_token CHANGING tokens error_message.
    ELSE.
      RAISE invalid_communication.
    ENDIF.

  ENDIF.

ENDFUNCTION.

FORM rtg_sap_rest USING carrierconfig TYPE /pweaver/cconfig
                        ship_url TYPE /pweaver/shipurl
                     is_token TYPE /pweaver/tokens
               CHANGING tokens TYPE /pweaver/tokens
                 error_message TYPE string.

  DATA: lv_json_string TYPE string.
*  DATA: lv_refresh_token TYPE string.
  DATA: lv_refresh_token TYPE /pweaver/refresh_token.
  CONSTANTS: lc_fedex    TYPE string VALUE 'FEDEX',
             lc_ups      TYPE string VALUE 'UPS',
             lc_tforceft TYPE string VALUE 'TFORCEFREIGHT'.

  CLEAR lv_json_string.
  IF carrierconfig-carriertype = lc_fedex.

    IF ship_url-username IS INITIAL.
      CONCATENATE 'grant_type='
                  ship_url-namespace
                  '& client_id='
                  ship_url-childkey
                  '& client_secret='
                  ship_url-childsecret
      INTO lv_json_string.
    ELSE.
      CONCATENATE 'grant_type='
                  ship_url-namespace
                  '& client_id='
                  ship_url-childkey
                  '& client_secret='
                  ship_url-childsecret
                  '& child_key='
                  ship_url-username
                  '& child_secret='
                  ship_url-password
      INTO lv_json_string.
    ENDIF.
    CONDENSE: lv_json_string NO-GAPS.

  ENDIF."fedex

  IF carrierconfig-carriertype = lc_ups.
    CONCATENATE 'grant_type='
    ship_url-namespace
    '&refresh_token='
    is_token-refresh_token
    INTO lv_json_string.
  ENDIF. "ups

  IF carrierconfig-carrieridf = lc_tforceft.
    CONCATENATE 'client_id=' carrierconfig-userid
                '&client_secret=' carrierconfig-password
                '&grant_type=' ship_url-namespace
                '&scope=' ship_url-soapaction
                '&refresh_token=' is_token-refresh_token
    INTO lv_json_string.
  ENDIF."tforce freight


  IF lv_json_string IS NOT INITIAL.
    DATA: http_status          TYPE i,
          status               TYPE string,
          http_response_string TYPE string.

    CALL FUNCTION '/PWEAVER/REST_COMMUNICATION'
      EXPORTING
        carrierconfig        = carrierconfig
        shipurl              = ship_url
        tokens               = is_token
        json_string          = lv_json_string
      IMPORTING
        http_status          = http_status
        status               = status
        http_response_string = http_response_string.
  ENDIF.


  IF http_response_string IS NOT INITIAL.
    CASE http_status.
      WHEN '200'.
        PERFORM read_token USING http_response_string CHANGING tokens error_message.
        IF tokens-access_token IS NOT INITIAL.
          lv_refresh_token = tokens-refresh_token.
          CALL FUNCTION '/PWEAVER/UPDATE_ACCESS_TOKEN'
            EXPORTING
              carrierconfig = carrierconfig
              access_token  = tokens-access_token
              refresh_token = lv_refresh_token
              shipurl       = ship_url.
        ENDIF.
      WHEN OTHERS.
        PERFORM read_error USING http_response_string CHANGING error_message.
    ENDCASE.
  ENDIF.


ENDFORM.

FORM read_token USING json_string TYPE string
             CHANGING token TYPE /pweaver/tokens
                      error_message TYPE string.

  DATA: BEGIN OF abap_result,
          access_token  TYPE string VALUE IS INITIAL,
          refresh_token TYPE string VALUE IS INITIAL,
        END OF abap_result.

  DATA lv_exception TYPE REF TO cx_xslt_format_error.
  TRY.
      CALL TRANSFORMATION id SOURCE XML json_string RESULT result = abap_result.

    CATCH cx_xslt_format_error INTO lv_exception.
      CALL METHOD lv_exception->if_message~get_text
        RECEIVING
          result = error_message.
  ENDTRY.

  IF abap_result-access_token IS NOT INITIAL.
    token-access_token  = abap_result-access_token.
    token-refresh_token = abap_result-refresh_token.
  ENDIF.

ENDFORM.

FORM read_error USING json_string TYPE string
             CHANGING error_message TYPE string.


  TYPES: BEGIN OF t_errors3,
           code    TYPE string,
           message TYPE string,
         END OF t_errors3.
  TYPES: tt_errors3 TYPE STANDARD TABLE OF t_errors3 WITH DEFAULT KEY.
  DATA: BEGIN OF abap_result,
          customer_transaction_id TYPE string VALUE IS INITIAL,
          errors                  TYPE tt_errors3 VALUE IS INITIAL,
          transaction_id          TYPE string VALUE IS INITIAL,
        END OF abap_result.
  DATA ls_error TYPE t_errors3.
  DATA lv_exception TYPE REF TO cx_xslt_format_error.
  TRY.
      CALL TRANSFORMATION id SOURCE XML json_string RESULT result = abap_result.
      READ TABLE abap_result-errors INTO ls_error INDEX 1.
      IF sy-subrc = 0.
        CONCATENATE ls_error-code ':' ls_error-message INTO error_message SEPARATED BY space.
      ENDIF.
    CATCH cx_xslt_format_error INTO lv_exception.
      CALL METHOD lv_exception->if_message~get_text
        RECEIVING
          result = error_message.
  ENDTRY.

ENDFORM.
