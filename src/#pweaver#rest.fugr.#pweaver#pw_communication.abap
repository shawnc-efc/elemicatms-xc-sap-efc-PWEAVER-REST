FUNCTION /pweaver/pw_communication.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(SHIPPER) TYPE  /PWEAVER/ECSADDRESS OPTIONAL
*"     VALUE(SHIPMENT) TYPE  /PWEAVER/ECSSHIPMENT OPTIONAL
*"     VALUE(PRODUCT) TYPE  /PWEAVER/PRODUCT OPTIONAL
*"     VALUE(CARRIERCONFIG) TYPE  /PWEAVER/CCONFIG OPTIONAL
*"     VALUE(PRINTERCONFIG) TYPE  /PWEAVER/PRINTCF OPTIONAL
*"     VALUE(WS_REQ) TYPE  STRING OPTIONAL
*"     VALUE(FILENAME) TYPE  STRING OPTIONAL
*"     VALUE(PLANT) TYPE  /PWEAVER/CCONFIG-PLANT OPTIONAL
*"     VALUE(ACTION) OPTIONAL
*"     VALUE(NORESPONSE) TYPE  CHAR1 OPTIONAL
*"     VALUE(CARRIER_URL) TYPE  /PWEAVER/SHIPURL OPTIONAL
*"     VALUE(SM59_DESTINATION) TYPE  /PWEAVER/SHIPURL-RFCDESTINATION
*"       OPTIONAL
*"     VALUE(URLSTRING) TYPE  CHAR1 OPTIONAL
*"     VALUE(XCARRIER) TYPE  /PWEAVER/XSERVER OPTIONAL
*"     VALUE(REQUEST_XML) TYPE  /PWEAVER/TT_STRING OPTIONAL
*"     VALUE(USERNAME) TYPE  STRING OPTIONAL
*"     VALUE(PASSWORD) TYPE  STRING OPTIONAL
*"     VALUE(AUTHORIZATION) TYPE  STRING OPTIONAL
*"  EXPORTING
*"     REFERENCE(RESPONSE_XML) TYPE  /PWEAVER/TT_STRING
*"     REFERENCE(WS_RESP) TYPE  STRING
*"     REFERENCE(TRACKINGINFO) TYPE  /PWEAVER/ECSTRACK
*"     REFERENCE(RESPONSE_XML_OBJECT) TYPE REF TO  IF_IXML_DOCUMENT
*"     REFERENCE(LABELDATA)
*"     REFERENCE(STATUS_LOG)
*"     REFERENCE(IPD_DATA)
*"     REFERENCE(LT_AES_DATA) TYPE  /PWEAVER/TT_STRING
*"  TABLES
*"      PACKAGES STRUCTURE  /PWEAVER/ECSPACKAGES OPTIONAL
*"----------------------------------------------------------------------


  DATA   gs_xml_xstr       TYPE xstring.

*  DATA: obj_document   TYPE REF TO if_ixml_document,
*    obj_node       TYPE REF TO if_ixml_node,
*    obj_iterator   TYPE REF TO if_ixml_node_iterator,
*    lv_name        TYPE string.

*  DATA :   obj_responses TYPE REF TO if_ixml_node_collection,
*           obj_response TYPE REF TO if_ixml_element,
*           gv_resp_count TYPE i,
*           gv_counter TYPE i.


  IF xcarrier-xcarrier = 'X' AND carrier_url-communication = 'XCARRIER'.
    IF action IS INITIAL.
      action = 'LTL'.
    ENDIF.

*    CALL FUNCTION '/PWEAVER/PW_SIG_COMMUNICATION'
*      EXPORTING
*        shipper             = shipper
*        shipto              = shipto
*        shipment            = shipment
*        product             = product
*        carrierconfig       = carrierconfig
*        xcarrier            = xcarrier
*        printerconfig       = printerconfig
*        ws_req              = ws_req
*        filename            = filename
*        plant               = plant
*        action              = action
*        noresponse          = noresponse
*        carrier_url         = carrier_url
*        sm59_destination    = sm59_destination
*        urlstring           = urlstring
*        request_xml         = request_xml
*        username            = username
*        password            = password
*        authorization       = authorization
*      IMPORTING
*        response_xml        = response_xml
*        ws_resp             = ws_resp
*        trackinginfo        = trackinginfo
*        response_xml_object = response_xml_object
*        labeldata           = labeldata
*        status_log          = status_log
*        ipd_data            = ipd_data
*        lt_aes_data         = lt_aes_data
*      TABLES
*        packages            = packages
*      EXCEPTIONS
*        connection_error    = 1
*        OTHERS              = 2.
*    IF sy-subrc <> 0.
** Implement suitable error handling here
*    ENDIF.

*    CALL FUNCTION 'ZPW_BAPI_CALL_XCARRIER'
*      EXPORTING
*        carrier_text     = ws_req
*        filename         = filename
*        carrierconfig    = carrierconfig
*        xserver          = xcarrier
*        action           = action
*      IMPORTING
*        trackinginfo     = trackinginfo
*        responce_text    = ws_resp
*        labeldata        = labeldata
*      TABLES
*        packages         = packages
*      EXCEPTIONS
*        connection_error = 1
*        OTHERS           = 2.
*    IF sy-subrc <> 0.
** Implement suitable error handling here
*    ENDIF.
*    .

  ELSEIF carrierconfig-iorcode_ipd = 'API' OR carrier_url-communication = 'SAP'.
*    CALL FUNCTION '/PWEAVER/ECS_HTTPCOMMUNICATION'
*      EXPORTING
*        ws_req           = ws_req
*        filename         = filename
*        plant            = plant
*        action           = action
*        noresponse       = noresponse
*        carrier_url      = carrier_url
*        sm59_destination = sm59_destination
*        urlstring        = urlstring
*        username         = username
*        password         = password
*        authorization    = authorization
*      IMPORTING
*        response_xml     = response_xml
*        ws_resp          = ws_resp
*      EXCEPTIONS
*        connection_error = 1
*        OTHERS           = 2.
*    IF sy-subrc <> 0.
** Implement suitable error handling here
*    ENDIF.



  ELSEIF  carrierconfig-iorcode_ipd = 'EXE' OR carrier_url-communication = 'EXE'.
    CALL FUNCTION '/PWEAVER/ECS_EXE_COMMUNICATION'
      EXPORTING
        request_xml     = request_xml
        filename        = filename
        plant           = carrierconfig-plant
        imp_request     = ws_req
      IMPORTING
*       response_xml    = lt_xml
        response_string = ws_resp.
  ENDIF.

  IF ws_resp IS NOT INITIAL.
    DATA:
          ls_xml TYPE string.
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

    DATA : str(100) TYPE c.

* Convert string to xstring
    cl_trex_char_utility=>convert_to_utf8(
         EXPORTING
           im_char_string =  ws_resp
         IMPORTING
           ex_utf8_string =  gs_xml_xstr  ).
    """""""""""""""""""""""""""""""""""""""""'
    CALL FUNCTION 'SDIXML_XML_TO_DOM'
      EXPORTING
        xml           = gs_xml_xstr
*       SIZE          = resp_len
*       IS_NORMALIZING = 'X'
      IMPORTING
        document      = response_xml_object
      EXCEPTIONS
        invalid_input = 0
        OTHERS        = 0.
*CALL FUNCTION 'SDIXML_DOM_TO_SCREEN'
*  EXPORTING
*    document          =  response_xml_object
**   TITLE             =
** EXCEPTIONS
**   NO_DOCUMENT       = 1
**   OTHERS            = 2
*          .
*IF sy-subrc <> 0.
** Implement suitable error handling here
*ENDIF.


*    shipment-responsexml = ws_resp.
*"""""""""""""""""""""""""""""""""""""""""""""
  ENDIF.







ENDFUNCTION.
