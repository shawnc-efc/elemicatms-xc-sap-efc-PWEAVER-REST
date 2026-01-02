FUNCTION /pweaver/rest_communication.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(CARRIERCONFIG) TYPE  /PWEAVER/CCONFIG OPTIONAL
*"     VALUE(SHIPURL) TYPE  /PWEAVER/SHIPURL OPTIONAL
*"     VALUE(TOKENS) TYPE  /PWEAVER/TOKENS OPTIONAL
*"     VALUE(JSON_STRING) TYPE  /PWEAVER/STRING OPTIONAL
*"  EXPORTING
*"     VALUE(HTTP_STATUS) TYPE  I
*"     VALUE(STATUS) TYPE  STRING
*"     VALUE(HTTP_RESPONSE_STRING) TYPE  STRING
*"----------------------------------------------------------------------


*  CHECK json_string IS NOT INITIAL.
  CHECK shipurl IS NOT INITIAL.

  CONSTANTS: lc_content_type    TYPE string VALUE 'Content-Type',
             lc_authorization   TYPE string VALUE 'Authorization',
             lc_appl_json       TYPE string VALUE 'application/json',
             lc_appl_urlencoded TYPE string VALUE 'application/x-www-form-urlencoded'.

  CONSTANTS: lc_bearer TYPE string VALUE 'Bearer',
             lc_t      TYPE char1  VALUE 'T',
             lc_x      TYPE char1  VALUE 'X',
             lc_basic  TYPE char10 VALUE 'Basic',
             lc_get    TYPE char5  VALUE 'GET',
             lc_pipe   TYPE char1  VALUE '|',
             lc_colon  TYPE char1  VALUE ':'.
*             lc_urlencoded TYPE string VALUE 'application/x-www-form-urlencoded'.

  DATA: lobj_http_client TYPE REF TO if_http_client,
        lv_url_rest      TYPE string,
        restmethod       TYPE string,
        content_type     TYPE string,
        lv_token         TYPE string,
        lv_ups_ett_url   TYPE string,
        lv_name          TYPE string,
        lv_value         TYPE string,
        lt_hdr_key       TYPE TABLE OF string,
        ls_hdr_key       TYPE string.

  IF shipurl-cccategory = lc_t.
    lv_url_rest = shipurl-testurl.
  ELSE.
    lv_url_rest = shipurl-prdurl.
  ENDIF.
  IF json_string IS INITIAL AND shipurl-urlstring = lc_x.
    lv_url_rest = shipurl-soapaction.
  ENDIF.
  restmethod = shipurl-restmethod.
  content_type = shipurl-contenttype.
*** in the S4 upgrade the direct communication is not working so we are change it to using the SM59 connection to communicate
  cl_http_client=>create_by_url(
  EXPORTING
    url                    = lv_url_rest
  IMPORTING
    client                 = lobj_http_client
  EXCEPTIONS
    argument_not_found     = 1
    plugin_not_active      = 2
    internal_error         = 3
*    pse_not_found          = 4
*    pse_not_distrib        = 5
*    pse_errors             = 6
    OTHERS                 = 7 ).

*  DATA: lv_destination TYPE c LENGTH 10.
*  IF shipurl-pwmodule = 'RTG'.
*    lv_destination = 'UPS_RTG'.
*  ELSE.
*    lv_destination = 'UPS_RS'.
*  ENDIF.
*
*  CALL METHOD cl_http_client=>create_by_destination
*    EXPORTING
*      destination              = lv_destination
*    IMPORTING
*      client                   = lobj_http_client
*    EXCEPTIONS
*      argument_not_found       = 1
*      destination_not_found    = 2
*      destination_no_authority = 3
*      plugin_not_active        = 4
*      internal_error           = 5
*      OTHERS                   = 6.

  IF sy-subrc EQ 0.
    lobj_http_client->propertytype_logon_popup = if_http_client=>co_disabled.

    lobj_http_client->request->set_method( restmethod ).

    lobj_http_client->request->set_header_field( name  = lc_content_type
                                                 value = content_type ).

    IF shipurl-urlstring = lc_x AND shipurl-namespace IS NOT INITIAL.
      SPLIT shipurl-namespace AT lc_pipe INTO TABLE lt_hdr_key.
      LOOP AT lt_hdr_key INTO ls_hdr_key.
        SPLIT ls_hdr_key AT lc_colon INTO lv_name lv_value.
        IF lv_name IS NOT INITIAL AND
           lv_value IS NOT INITIAL.
          lobj_http_client->request->set_header_field( name  = lv_name
                                                       value = lv_value ).
        ENDIF.
      ENDLOOP.
    ENDIF.

    IF shipurl-authorization_type = lc_bearer.
      CONCATENATE shipurl-authorization_type tokens-access_token INTO lv_token SEPARATED BY space.

      lobj_http_client->request->set_header_field( name  = lc_authorization
                                                   value = lv_token ).
    ENDIF.

    IF shipurl-authorization_type = lc_basic.
      DATA l_username TYPE string.
      DATA l_password TYPE string.

      l_username = carrierconfig-userid.
      l_password = carrierconfig-password.
      CALL METHOD lobj_http_client->authenticate
        EXPORTING
          username = l_username
          password = l_password.
    ENDIF.

    DATA: http_request_string TYPE string.
    IF shipurl-contenttype = lc_appl_urlencoded.
      DATA: json_xstring TYPE xstring.
      CLEAR json_xstring.
      CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
        EXPORTING
          text   = json_string
*         MIMETYPE       = ' '
*         ENCODING       =
        IMPORTING
          buffer = json_xstring
        EXCEPTIONS
          failed = 1
          OTHERS = 2.
      IF sy-subrc = 0.
        lobj_http_client->request->set_data( json_xstring ).

        http_request_string = lobj_http_client->request->get_cdata( ).

      ELSE.
        CLEAR: json_xstring.
      ENDIF.
    ELSE.
      lobj_http_client->request->set_cdata( json_string ).

      http_request_string = lobj_http_client->request->get_cdata( ).
    ENDIF.



    TRY.
        lobj_http_client->send( ).
        lobj_http_client->receive(
        EXCEPTIONS
          http_communication_failure = 1
          http_invalid_state         = 2
          http_processing_failed     = 3
          OTHERS                     = 4 ).
        IF sy-subrc EQ 0.
          CLEAR http_response_string.
          lobj_http_client->response->get_status( IMPORTING code = http_status
                                                          reason = status ).

          http_response_string = lobj_http_client->response->get_cdata( ).

        ENDIF.
      CATCH  cx_root.

    ENDTRY.

  ENDIF.


  IF shipurl-contenttype = lc_appl_json OR shipurl-contenttype = lc_appl_urlencoded.
    DATA: match_tab     TYPE match_result_tab,
          ls_match      LIKE LINE OF match_tab,
          lv_end_offset TYPE i.
    DATA: lv_lowercase_string TYPE string,
          lv_uppercase_string TYPE string.


    REPLACE ALL OCCURRENCES OF '"false"' IN http_response_string WITH 'false'.
    REPLACE ALL OCCURRENCES OF '"true"' IN http_response_string WITH 'true'.
    REPLACE ALL OCCURRENCES OF 'false' IN http_response_string WITH '"false"'.
    REPLACE ALL OCCURRENCES OF 'true' IN http_response_string WITH '"true"'.

    FIND ALL OCCURRENCES OF REGEX '":' IN http_response_string RESULTS match_tab.
    IF sy-subrc = 0.
      DATA loop_offset TYPE i.
      LOOP AT match_tab INTO ls_match.
        loop_offset = ls_match-offset - 1.
        WHILE loop_offset >= 1.
          IF http_response_string+loop_offset(1) = '"'.
            lv_end_offset = ( ls_match-offset - loop_offset ) + 2.
            lv_uppercase_string = lv_lowercase_string = http_response_string+loop_offset(lv_end_offset).
            TRANSLATE lv_uppercase_string TO UPPER CASE.
            REPLACE ALL OCCURRENCES OF '.' IN lv_uppercase_string WITH '_'.
            REPLACE ALL OCCURRENCES OF lv_lowercase_string IN http_response_string WITH lv_uppercase_string.
            EXIT.
          ELSE.
            loop_offset = loop_offset - 1.
          ENDIF.
        ENDWHILE.
      ENDLOOP.
    ENDIF.

    CONCATENATE '{"RESULT":'  http_response_string '}' INTO http_response_string.

  ENDIF.



ENDFUNCTION.
