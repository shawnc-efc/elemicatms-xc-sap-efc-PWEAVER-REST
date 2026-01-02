FUNCTION /pweaver/ecs_exe_communication.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(REQUEST_XML) TYPE  /PWEAVER/TT_STRING OPTIONAL
*"     VALUE(FILENAME) TYPE  STRING OPTIONAL
*"     VALUE(PLANT) TYPE  /PWEAVER/CCONFIG-PLANT OPTIONAL
*"     VALUE(ACTION) OPTIONAL
*"     VALUE(NORESPONSE) TYPE  CHAR1 OPTIONAL
*"     VALUE(COMMUNICATION_URL) TYPE  /PWEAVER/SHIPURL OPTIONAL
*"     VALUE(IMP_REQUEST) TYPE  STRING OPTIONAL
*"  EXPORTING
*"     VALUE(RESPONSE_XML) TYPE  /PWEAVER/TT_STRING
*"     VALUE(RESPONSE_STRING) TYPE  STRING
*"----------------------------------------------------------------------

  DATA: download_filename TYPE string,
        upload_filename   TYPE string.

  DATA: request_download_xml TYPE  /pweaver/tt_string .

  DATA lv_parva TYPE usr05-parva.


  SELECT SINGLE parva FROM usr05 INTO lv_parva WHERE bname = sy-uname AND parid = '/PWEAVER/DEBUG'.

  DATA : ws_req  TYPE string,
         ws_resp TYPE string.
  DATA   ls_xml TYPE string.
  DATA:" ls_citrix TYPE /pweaver/citrix,
        lv_path   TYPE string.
  DATA:lt_filedownload TYPE TABLE OF /pweaver/ecsfile,
       ls_filedownload LIKE LINE OF lt_filedownload.

  IF request_xml[] IS INITIAL.
    ws_req = imp_request.
  ENDIF.
  SELECT  SINGLE * FROM /pweaver/ecsfile INTO ls_filedownload WHERE username = sy-uname.
  IF ls_filedownload-requestpath <> '' AND ls_filedownload-responsepath <> ''.
    CONCATENATE ls_filedownload-requestpath filename INTO download_filename.
  ELSE.
*    SELECT SINGLE * FROM /pweaver/citrix INTO ls_citrix WHERE vstel = plant.
    IF sy-subrc = 0.
**    if the shipping point is confgiuref for citirx
      CALL METHOD cl_gui_frontend_services=>environment_get_variable
        EXPORTING
          variable             = 'TEMP'
        CHANGING
          value                = lv_path
        EXCEPTIONS
          cntl_error           = 0
          error_no_gui         = 0
          not_supported_by_gui = 0
          OTHERS               = 0.
*      IF SY-SUBRC <> 0.
** MESSAGE ID SY-MSGID TYPE SY-MSGTY NUMBER SY-MSGNO
**            WITH SY-MSGV1 SY-MSGV2 SY-MSGV3 SY-MSGV4.
*      ENDIF.

      CALL METHOD cl_gui_cfw=>flush
        EXCEPTIONS
          cntl_system_error = 1
          cntl_error        = 2
          OTHERS            = 3.
      IF sy-subrc <> 0.
        MESSAGE ID sy-msgid TYPE sy-msgty NUMBER sy-msgno
                   WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      ENDIF.

      DATA temp TYPE string.                                "#EC NEEDED
      SPLIT lv_path AT 'Temp'(003) INTO lv_path temp.
      CONCATENATE lv_path 'Temp'(003) INTO lv_path.
      CONCATENATE lv_path '\Shipping\ECS\Request\' filename INTO download_filename.
    ELSE.
      CONCATENATE  'C:\Shipping\ECS\Request\' filename INTO download_filename.
    ENDIF.
  ENDIF.

  DATA xreqstr TYPE xstring.
  IF lv_parva = 'X'.
    IF request_xml[] IS NOT INITIAL.
      LOOP AT request_xml INTO ls_xml.
        CONCATENATE ws_req ls_xml INTO ws_req.
      ENDLOOP.
    ENDIF.
    CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
      EXPORTING
        text   = ws_req
      IMPORTING
        buffer = xreqstr.
*    PERFORM display USING xreqstr.
  ENDIF.

*  IF sy-uname = 'PWDEV'.
*    request_download_xml[] = request_xml[].
*    CALL METHOD cl_gui_frontend_services=>gui_download
*      EXPORTING
*        filename                = download_filename
*        filetype                = 'ASC'
*      CHANGING
*        data_tab                = request_download_xml[]
*      EXCEPTIONS
*        file_write_error        = 1
*        no_batch                = 2
*        gui_refuse_filetransfer = 3
*        invalid_type            = 4
*        no_authority            = 5
*        unknown_error           = 6
*        header_not_allowed      = 7
*        separator_not_allowed   = 8
*        filesize_not_allowed    = 9
*        header_too_long         = 10
*        dp_error_create         = 11
*        dp_error_send           = 12
*        dp_error_write          = 13
*        unknown_dp_error        = 14
*        access_denied           = 15
*        dp_out_of_memory        = 16
*        disk_full               = 17
*        dp_timeout              = 18
*        file_not_found          = 19
*        dataprovider_exception  = 20
*        control_flush_error     = 21
*        not_supported_by_gui    = 22
*        error_no_gui            = 23
*        OTHERS                  = 24.
*  ELSE.
  IF request_xml[] IS NOT INITIAL.
    CLEAR ws_req.
    LOOP AT request_xml INTO ls_xml.
      CONCATENATE ws_req ls_xml INTO ws_req.
    ENDLOOP.
  ENDIF.
  IF ws_req IS NOT INITIAL.

    DATA : resp_xstring TYPE xstring.

    DATA: l_ixml          TYPE REF TO if_ixml,
          l_streamfactory TYPE REF TO if_ixml_stream_factory,
          l_parser        TYPE REF TO if_ixml_parser,
          l_istream       TYPE REF TO if_ixml_istream,
          l_document      TYPE REF TO if_ixml_document.

    DATA: parseerror TYPE REF TO if_ixml_parse_error,
          i          TYPE i,
          index      TYPE i.

    DATA: node  TYPE REF TO if_ixml_node,
          name  TYPE string,
          value TYPE string.
    DATA   gs_xml_xstr       TYPE xstring.
    DATA : str(100) TYPE c.

* Convert string to xstring
    cl_trex_char_utility=>convert_to_utf8(
         EXPORTING
           im_char_string =  ws_req
         IMPORTING
           ex_utf8_string =  gs_xml_xstr  ).
    """""""""""""""""""""""""""""""""""""""""'
    DATA: xmllength TYPE i.
    DATA binary_tab TYPE sdokcntbins.
    REFRESH  request_download_xml.
    CALL FUNCTION 'SCMS_XSTRING_TO_BINARY'
      EXPORTING
        buffer        = gs_xml_xstr
*       APPEND_TO_TABLE       = ' '
      IMPORTING
        output_length = xmllength
      TABLES
        binary_tab    = binary_tab.

    CALL METHOD cl_gui_frontend_services=>gui_download
      EXPORTING
        filename                = download_filename
        filetype                = 'BIN'
*        filetype                = 'ASC'
      CHANGING
        data_tab                = binary_tab[]
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
        not_supported_by_gui    = 22
        error_no_gui            = 23
        OTHERS                  = 24.

*"""""""""""""""""""""""""""""""""""""""""""""
  ENDIF.



  REFRESH request_download_xml.
  IF lv_path IS NOT INITIAL.
    CONCATENATE lv_path '\Shipping\ECS\Response\'  filename  INTO upload_filename.
  ELSE.
    IF ls_filedownload-requestpath <> '' AND ls_filedownload-responsepath <> ''.
      CONCATENATE ls_filedownload-responsepath filename INTO upload_filename.
    ELSE.
      CONCATENATE 'C:\Shipping\ECS\Response\' filename '*'  INTO upload_filename.
    ENDIF.
  ENDIF.
*  REFRESH XML.

  IF action <> 'REPRINT'.
    DO 200 TIMES.
      CALL METHOD cl_gui_frontend_services=>gui_upload
        EXPORTING
          filename                = upload_filename
          filetype                = 'ASC'
        CHANGING
          data_tab                = response_xml[]
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
          not_supported_by_gui    = 17
          error_no_gui            = 18
          OTHERS                  = 19.
      IF sy-subrc <> 0.
        WAIT UP TO 2 SECONDS.
      ELSE.
        EXIT.
      ENDIF.
    ENDDO.
  ENDIF.
  IF NOT response_xml[] IS INITIAL.
    DATA xstr TYPE xstring.
    CLEAR ws_resp.
    LOOP AT response_xml INTO ls_xml.
      CONCATENATE ws_resp ls_xml INTO ws_resp.
    ENDLOOP.
    response_string = ws_resp.
    IF lv_parva = 'X'.
      CALL FUNCTION 'SCMS_STRING_TO_XSTRING'
        EXPORTING
          text   = ws_resp
        IMPORTING
          buffer = xstr.
*      PERFORM display USING xstr.
    ENDIF.
  ENDIF.


ENDFUNCTION.
