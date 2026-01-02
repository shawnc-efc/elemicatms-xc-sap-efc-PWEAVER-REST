FUNCTION /pweaver/void_global.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     REFERENCE(CARRIERCONFIG) TYPE  /PWEAVER/CCONFIG OPTIONAL
*"     VALUE(TRACKING_NUMBER) OPTIONAL
*"     VALUE(OPTION) OPTIONAL
*"     VALUE(SHIPTO_COUNTRY) OPTIONAL
*"  EXPORTING
*"     REFERENCE(ERROR)
*"  TABLES
*"      TRACKING_NUMBERS STRUCTURE  /PWEAVER/ECSPACKAGES OPTIONAL
*"----------------------------------------------------------------------

  DATA : file_out  TYPE string,
         file_in   TYPE string,
         file_name TYPE string,
         srv_resp  TYPE string.

  DATA: ds_return TYPE /pweaver/ds_void_xslt_resp.
  DATA : lt_xml TYPE TABLE OF string,
         ls_xml TYPE string.
  DATA : sin TYPE /pweaver/manfest-tracking_number.
  DATA: lt_shipurl TYPE TABLE OF /pweaver/shipurl,
        ls_shipurl TYPE /pweaver/shipurl.
  DATA: communication_url TYPE /pweaver/shipurl.
  DATA: url(132) TYPE  c.
  DATA : cancel_trktab TYPE TABLE OF string,
         cancel_trk    TYPE string.
  CONSTANTS: lc_true TYPE char10 VALUE 'TRUE',
             lc_t    TYPE char1 VALUE 'T'.

*  DATA ls_void_req TYPE /pweaver/ds_ett_xslt_req.

*  DATA it_track TYPE /PWEAVER/TT_ett_xslt_track_req.

  DATA lv_file_name TYPE string.

  SELECT * FROM /pweaver/shipurl INTO TABLE lt_shipurl WHERE systemid = sy-sysid AND

  pwmodule = 'ECSCANCEL'.

  IF sy-subrc = 0.

    READ TABLE lt_shipurl INTO communication_url WITH KEY

                                                     plant = carrierconfig-plant

                                                     carriertype = carrierconfig-lifnr.

    IF sy-subrc <> 0.

      READ TABLE lt_shipurl INTO communication_url WITH KEY   plant = carrierconfig-plant

                                                      carriertype = carrierconfig-carrieridf.

      IF sy-subrc <> 0.

        READ TABLE lt_shipurl INTO communication_url WITH KEY  plant = carrierconfig-plant

                                                        carriertype = carrierconfig-carriertype.

        IF sy-subrc <> 0.

          READ TABLE lt_shipurl INTO communication_url WITH KEY  carriertype = carrierconfig-lifnr.

          IF sy-subrc <> 0.

            READ TABLE lt_shipurl INTO communication_url WITH KEY  carriertype = carrierconfig-carrieridf.

            IF sy-subrc <> 0.

              READ TABLE lt_shipurl INTO communication_url WITH KEY  carriertype = carrierconfig-carriertype.

            ENDIF.

          ENDIF.

        ENDIF.

      ENDIF.

    ENDIF.

  ENDIF.



  IF communication_url IS INITIAL.

    MESSAGE i221(/pweaver/ecs_v1) WITH communication_url-carriertype communication_url-pwmodule RAISING error.

    RETURN.

  ELSEIF communication_url-communication IS INITIAL.

    MESSAGE i170(/pweaver/ecs_v1) RAISING error.

    RETURN.

  ELSEIF communication_url-communication = 'XCARRIER' ."AND xcarrier IS INITIAL.

    MESSAGE i171(/pweaver/ecs_v1) RAISING error.

  ELSEIF communication_url-filename IS INITIAL AND communication_url-communication <> 'API'.

    MESSAGE i239(/pweaver/ecs_v1) RAISING error.

  ENDIF.



  IF communication_url-cccategory = 'T'.

    CONCATENATE communication_url-hostport '://'  communication_url-testurl communication_url-pathprefix INTO url.

  ELSE.

    CONCATENATE communication_url-hostport '://'  communication_url-prdurl communication_url-pathprefix INTO url.

  ENDIF.

********



**  v_shipdate  = sy-datum .

**

**  CLEAR : gs_date .

**  CONCATENATE v_shipdate+0(4) v_shipdate+4(2) v_shipdate+6(2) INTO gs_date SEPARATED BY '-'.

  SELECT SINGLE tracking_number mastertracking FROM /pweaver/manfest INTO (tracking_number, sin)

    WHERE tracking_number = tracking_number AND canc_dt = '00000000'.



**Rest API Access Token

  DATA ls_token TYPE /pweaver/tokens.



  CALL FUNCTION '/PWEAVER/GET_ACCESS_TOKEN'
    EXPORTING
      carrierconfig   = carrierconfig
      shipurl         = communication_url
    IMPORTING
      tokens          = ls_token
    EXCEPTIONS
      no_tokens_found = 1
      OTHERS          = 2.

  IF sy-subrc <> 0.

* Implement suitable error handling here

  ENDIF.







  APPEND '<Request>' TO lt_xml.

  CONCATENATE '<Carrier>' 'UPS' '</Carrier>' INTO ls_xml.

  APPEND ls_xml TO lt_xml. CLEAR ls_xml.

  CONCATENATE '<RESTAPI>' 'TRUE' '</RESTAPI>' INTO ls_xml.

  APPEND ls_xml TO lt_xml. CLEAR ls_xml.

  CONCATENATE '<UserID>' carrierconfig-userid '</UserID>' INTO ls_xml.

  APPEND ls_xml TO lt_xml. CLEAR ls_xml.

  CONCATENATE '<Password>' carrierconfig-password '</Password>' INTO ls_xml.

  APPEND ls_xml TO lt_xml. CLEAR ls_xml.

  CONCATENATE '<CspKey>' carrierconfig-cspuserid '</CspKey>' INTO ls_xml.

  APPEND ls_xml TO lt_xml. CLEAR ls_xml.

  CONCATENATE '<CspPassword>' carrierconfig-csppassword '</CspPassword>' INTO ls_xml.

  APPEND ls_xml TO lt_xml. CLEAR ls_xml.

  CONCATENATE '<AccountNumber>' carrierconfig-accountnumber '</AccountNumber>' INTO ls_xml.

  APPEND ls_xml TO lt_xml. CLEAR ls_xml.

  CONCATENATE '<AccessToken>' ls_token-access_token '</AccessToken>' INTO ls_xml.

  APPEND ls_xml TO lt_xml. CLEAR ls_xml.

  CONCATENATE '<RefreshToken>' ls_token-refresh_token '</RefreshToken>' INTO ls_xml.

  APPEND ls_xml TO lt_xml. CLEAR ls_xml.

  CONCATENATE '<MeterNumber>' '</MeterNumber>' INTO ls_xml.

  APPEND ls_xml TO lt_xml. CLEAR ls_xml.

  CONCATENATE '<CustomerTransactionId>' '</CustomerTransactionId>' INTO ls_xml.

  APPEND ls_xml TO lt_xml. CLEAR ls_xml.

  CONCATENATE '<ShipDate>' sy-datum '</ShipDate>' INTO ls_xml.

  APPEND ls_xml TO lt_xml. CLEAR ls_xml.

*  IF shipto_country = 'US'.



    IF option = 'J'.





      SELECT tracking_number FROM /pweaver/manfest INTO TABLE

      cancel_trktab WHERE mastertracking = sin.



      LOOP AT cancel_trktab INTO cancel_trk.

        CONCATENATE '<TrackingNumber>' cancel_trk '</TrackingNumber>' INTO ls_xml.

        APPEND ls_xml TO lt_xml. CLEAR ls_xml.

      ENDLOOP.



    ELSE.



      APPEND ls_xml TO lt_xml.CLEAR ls_xml.

      CONCATENATE '<TrackingNumber>' tracking_number '</TrackingNumber>' INTO ls_xml.

      APPEND ls_xml TO lt_xml. CLEAR ls_xml.

    ENDIF.

*  ENDIF.

  CONCATENATE '<URL>' url '</URL>' INTO ls_xml.

  APPEND ls_xml TO lt_xml. CLEAR ls_xml.

  APPEND '</Request>' TO lt_xml.



  CONCATENATE communication_url-filename  sy-datlo sy-uzeit '.xml' INTO file_name.



  CONCATENATE 'C:\Shipping\ECS\Request\' file_name INTO file_out.



  CALL FUNCTION 'GUI_DOWNLOAD'
    EXPORTING
*     BIN_FILESIZE            =
      filename                = file_out
      filetype                = 'ASC'
*     APPEND                  = ' '
*     WRITE_FIELD_SEPARATOR   = ' '
*     HEADER                  = '00'
*     TRUNC_TRAILING_BLANKS   = ' '
*     WRITE_LF                = 'X'
*     COL_SELECT              = ' '
*     COL_SELECT_MASK         = ' '
*     DAT_MODE                = ' '
*     CONFIRM_OVERWRITE       = ' '
*     NO_AUTH_CHECK           = ' '
*     CODEPAGE                = ' '
*     IGNORE_CERR             = ABAP_TRUE
*     REPLACEMENT             = '#'
*     WRITE_BOM               = ' '
*     TRUNC_TRAILING_BLANKS_EOL       = 'X'
*     WK1_N_FORMAT            = ' '
*     WK1_N_SIZE              = ' '
*     WK1_T_FORMAT            = ' '
*     WK1_T_SIZE              = ' '
*     IMPORTING
*     FILELENGTH              =
    TABLES
      data_tab                = lt_xml
*     FIELDNAMES              =
    EXCEPTIONS
      file_write_error        = 1
      no_batch                = 2
      gui_refuse_filetransfer = 3
      invalid_type            = 4
      no_authority            = 5
      unknown_error           = 6
      header_not_allowed      = 7
      separator_not_allowed   = 8
      filesize_not_allowed    = 9
      header_too_long         = 10
      dp_error_create         = 11
      dp_error_send           = 12
      dp_error_write          = 13
      unknown_dp_error        = 14
      access_denied           = 15
      dp_out_of_memory        = 16
      disk_full               = 17
      dp_timeout              = 18
      file_not_found          = 19
      dataprovider_exception  = 20
      control_flush_error     = 21
      OTHERS                  = 22.

  IF sy-subrc <> 0.

    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno

            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.

  ENDIF.







  CONCATENATE 'C:\Shipping\ECS\Response\' file_name INTO file_in.





  REFRESH lt_xml.



  DATA : str(100) TYPE c.

  DATA : amount TYPE p DECIMALS 3.

  DATA : str_start TYPE i, str_end TYPE i.

  DATA: response_xml TYPE string.

  DATA obj TYPE REF TO cx_xslt_format_error.



  DO 2000 TIMES.



    CALL FUNCTION 'GUI_UPLOAD'
      EXPORTING
        filename                = file_in
        filetype                = 'ASC'
*       HAS_FIELD_SEPARATOR     = ' '
*       HEADER_LENGTH           = 0
*       READ_BY_LINE            = 'X'
*       DAT_MODE                = ' '
*       CODEPAGE                = ' '
*       IGNORE_CERR             = ABAP_TRUE
*       REPLACEMENT             = '#'
*       CHECK_BOM               = ' '
*     IMPORTING
*       FILELENGTH              =
*       HEADER                  =
      TABLES
        data_tab                = lt_xml
      EXCEPTIONS
        file_open_error         = 1
        file_read_error         = 2
        no_batch                = 3
        gui_refuse_filetransfer = 4
        invalid_type            = 5
        no_authority            = 6
        unknown_error           = 7
        bad_data_format         = 8
        header_not_allowed      = 9
        separator_not_allowed   = 10
        header_too_long         = 11
        unknown_dp_error        = 12
        access_denied           = 13
        dp_out_of_memory        = 14
        disk_full               = 15
        dp_timeout              = 16
        OTHERS                  = 17.

    IF sy-subrc = 0.

      EXIT.

    ENDIF.

  ENDDO.



  IF sy-subrc <> 0.

    MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno

            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.

  ENDIF.





  LOOP AT lt_xml INTO ls_xml.

    CONCATENATE response_xml ls_xml INTO response_xml.

  ENDLOOP.



  IF response_xml IS NOT INITIAL.

    TRY.

        CALL TRANSFORMATION /pweaver/void_xslt_resp SOURCE XML response_xml

                                      RESULT shipresponse = ds_return.
      CATCH cx_xslt_format_error INTO obj.

        CALL METHOD obj->if_message~get_text
          RECEIVING
            result = error.

    ENDTRY.
    IF ds_return IS NOT INITIAL AND ( ds_return-status-status_message IS INITIAL AND ds_return-error is INITIAL ).
       TRY.

        CALL TRANSFORMATION /pweaver/void_xslt_resp_retry SOURCE XML response_xml

                                      RESULT shipresponse = ds_return.
      CATCH cx_xslt_format_error INTO obj.

        CALL METHOD obj->if_message~get_text
          RECEIVING
            result = error.

    ENDTRY.

    ENDIF.



    IF ds_return IS NOT INITIAL.



      CALL FUNCTION '/PWEAVER/UPDATE_ACCESS_TOKEN'
        EXPORTING
          carrierconfig = carrierconfig
          access_token  = ds_return-accesstoken
          refresh_token = ds_return-refreshtoken.



    ENDIF.
  ENDIF.

ENDFUNCTION.
