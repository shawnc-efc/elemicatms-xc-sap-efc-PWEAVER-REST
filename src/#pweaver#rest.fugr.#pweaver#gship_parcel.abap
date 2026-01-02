FUNCTION /pweaver/gship_parcel.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(DELIVERY_NUMBER) OPTIONAL
*"     VALUE(SALES_ORDER_NUMBER) OPTIONAL
*"     VALUE(SOLDTO_PARTY) OPTIONAL
*"     VALUE(CUSTOMER_NUMBER) OPTIONAL
*"     VALUE(DISTRIBUTION_CHANNEL) OPTIONAL
*"     VALUE(SHIPTO_COMPANY) OPTIONAL
*"     VALUE(SHIPTO_CONTACT) OPTIONAL
*"     VALUE(SHIPTO_ADDRESS1) OPTIONAL
*"     VALUE(SHIPTO_ADDRESS2) OPTIONAL
*"     VALUE(SHIPTO_ADDRESS3) OPTIONAL
*"     VALUE(SHIPTO_CITY) OPTIONAL
*"     VALUE(SHIPTO_STATE) OPTIONAL
*"     VALUE(SHIPTO_POSTALCODE) OPTIONAL
*"     VALUE(SHIPTO_COUNTRY) OPTIONAL
*"     VALUE(SHIPTO_PHONE) OPTIONAL
*"     VALUE(CARRIER_CODE) OPTIONAL
*"     VALUE(RESIDENTIAL_FLAGDESC) OPTIONAL
*"     VALUE(COD_TYPE) OPTIONAL
*"     VALUE(COD_AMOUNT) OPTIONAL
*"     VALUE(DIMENSIONS) OPTIONAL
*"     VALUE(WEIGHT) OPTIONAL
*"     VALUE(CARRIERCONFIG) TYPE  /PWEAVER/CCONFIG OPTIONAL
*"     VALUE(CUSTOM_VALUE) OPTIONAL
*"     VALUE(PAYMENTCODE) OPTIONAL
*"     VALUE(PURCHASE_ORDER) OPTIONAL
*"     VALUE(DUTY_FLAG) OPTIONAL
*"     VALUE(THIRD_ZIP) OPTIONAL
*"     VALUE(THIRD_PTY_ACCOUNT_NUMBER) OPTIONAL
*"     VALUE(SATURDAY_FLAG) OPTIONAL
*"     VALUE(SIGNATURE1_TYPE) OPTIONAL
*"     VALUE(INSURANCE_AMOUNT) OPTIONAL
*"     VALUE(DTAX) OPTIONAL
*"     VALUE(HANDLING_UNIT) OPTIONAL
*"     VALUE(LARGE_FLAG) OPTIONAL
*"     VALUE(ADDITIONAL_FLAG) OPTIONAL
*"     VALUE(RETURN_FLAG) OPTIONAL
*"     VALUE(RELEASE_FLAG) OPTIONAL
*"     VALUE(RETURN_NOTIFICATION) OPTIONAL
*"     VALUE(PLANT) OPTIONAL
*"     VALUE(EMAIL) OPTIONAL
*"     VALUE(FROM_COMPANY) OPTIONAL
*"     VALUE(FROM_CONTACT) OPTIONAL
*"     VALUE(FROM_ADDRESS1) OPTIONAL
*"     VALUE(FROM_ADDRESS2) OPTIONAL
*"     VALUE(FROM_PHONE) OPTIONAL
*"     VALUE(FROM_CITY) OPTIONAL
*"     VALUE(FROM_STATE) OPTIONAL
*"     VALUE(FROM_COUNTRY) OPTIONAL
*"     VALUE(FROM_POSTALCODE) OPTIONAL
*"     VALUE(SHIPPER_EMAIL) OPTIONAL
*"     VALUE(THIRD_COUNTRY) OPTIONAL
*"     VALUE(WEIGHTUNIT) OPTIONAL
*"     VALUE(CURRENCYUNIT) OPTIONAL
*"     VALUE(DIM_UNIT) OPTIONAL
*"     VALUE(REFERENCE1) OPTIONAL
*"     VALUE(REFERENCE2) OPTIONAL
*"     VALUE(DTAX_ACCOUNT) OPTIONAL
*"     VALUE(REMOVECI) OPTIONAL
*"     VALUE(PREALERT) OPTIONAL
*"     VALUE(PACKAGINGTYPE) OPTIONAL
*"     VALUE(LARGEPACKAGEINDICATOR) OPTIONAL
*"     VALUE(ADDITIONAL_HANDLING) OPTIONAL
*"     VALUE(DRYICE) OPTIONAL
*"     VALUE(PRINTERNAME) OPTIONAL
*"     VALUE(PRINTERCONFIG) TYPE  /PWEAVER/PRINTCF OPTIONAL
*"     VALUE(EXTERNALDOC) TYPE  /PWEAVER/MANFEST-EXTERNALDOC OPTIONAL
*"  EXPORTING
*"     VALUE(TRACKING_NO)
*"     VALUE(ERROR)
*"     VALUE(FREIGHT_AMT)
*"     VALUE(DISCOUNT_FREIGHT)
*"     VALUE(LABEL_URL)
*"     VALUE(TRACKINGINFO) TYPE  /PWEAVER/ECSTRACK
*"  TABLES
*"      TRACKING_NUMBERS STRUCTURE  /PWEAVER/ECSPACKAGES OPTIONAL
*"      INT_COMD STRUCTURE  /PWEAVER/COMMODITY OPTIONAL
*"----------------------------------------------------------------------


  DATA: l_xml_node TYPE REF TO if_ixml_element,             "#EC NEEDED
        l_name     TYPE string,                             "#EC NEEDED
        l_value    TYPE string.

  DATA :"LABELDATA    TYPE TABLE OF /PWEAVER/LABELDATA,
*        LS_LABELDATA TYPE /PWEAVER/LABELDATA,
        ws_resp      TYPE string.
*dsp
** Build CArrier Block
  DATA : lt_xml      TYPE TABLE OF string,
         ls_xml      TYPE string,
         request_xml TYPE string,
         filename    TYPE string.
  DATA : gs_date TYPE char10 .
  DATA: lt_shipurl TYPE TABLE OF /pweaver/shipurl.
  DATA: communication_url TYPE /pweaver/shipurl.
  DATA: v_shipdate  TYPE sydatum.
  DATA: gt_carrier_block TYPE /pweaver/string_tab.
  communication_url-pwmodule = 'ECSSHIP'.

  DATA: url       TYPE /pweaver/url,
        ls_broker TYPE /pweaver/ecsaddress,
        ls_hold   TYPE /pweaver/ecsaddress,
        url_etd   TYPE /pweaver/url.

  SELECT  * FROM /pweaver/shipurl INTO TABLE lt_shipurl  WHERE systemid = sy-sysid
                                                          AND pwmodule = communication_url-pwmodule.
  IF sy-subrc = 0.
    READ TABLE lt_shipurl INTO communication_url WITH KEY
                                                     plant = plant
                                                     carriertype = carrierconfig-lifnr.
    IF sy-subrc <> 0.
*      READ TABLE lt_shipurl INTO communication_url WITH KEY   plant = plant
*                                                      carriertype = carrierconfig-carrieridf.
*      IF sy-subrc <> 0.
      READ TABLE lt_shipurl INTO communication_url WITH KEY  plant = plant
                                                      carriertype = carrierconfig-carriertype.
      IF sy-subrc <> 0.
        READ TABLE lt_shipurl INTO communication_url WITH KEY  carriertype = carrierconfig-lifnr.
        IF sy-subrc <> 0.
*            READ TABLE lt_shipurl INTO communication_url WITH KEY  carriertype = carrierconfig-carrieridf.
*            IF sy-subrc <> 0.
          READ TABLE lt_shipurl INTO communication_url WITH KEY  carriertype = carrierconfig-carriertype.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDIF.
*    ENDIF.
*  ENDIF.

  IF communication_url IS INITIAL.
    MESSAGE i221(/pweaver/ecs_v1) WITH communication_url-carriertype communication_url-pwmodule RAISING error.
    RETURN.
  ELSEIF communication_url-communication IS INITIAL.
    MESSAGE i170(/pweaver/ecs_v1) RAISING error.
    RETURN.
*  ELSEIF communication_url-communication = 'XCARRIER' AND xcarrier IS INITIAL.
*    MESSAGE i171(/pweaver/ecs_v1) RAISING error.
  ELSEIF communication_url-filename IS INITIAL AND communication_url-communication <> 'API'.
    MESSAGE i239(/pweaver/ecs_v1) RAISING error.
  ENDIF.

  IF communication_url-cccategory = 'T'.
    CONCATENATE communication_url-hostport '://'  communication_url-testurl communication_url-pathprefix INTO url.
  ELSE.
    CONCATENATE communication_url-hostport '://'  communication_url-prdurl communication_url-pathprefix INTO url.
  ENDIF.

  v_shipdate = sy-datum.
  IF v_shipdate IS INITIAL .
    v_shipdate  = sy-datum .
  ENDIF  .
  CLEAR : gs_date .
  CONCATENATE v_shipdate+0(4) v_shipdate+4(2) v_shipdate+6(2) INTO gs_date SEPARATED BY '-'.

  IF communication_url-carriermethod = 'REST'.
    CONCATENATE '<RESTAPI>' 'TRUE' '</RESTAPI>' INTO ls_xml.
  ELSE.
    CONCATENATE '<RESTAPI>' 'NO' '</RESTAPI>' INTO ls_xml.
  ENDIF.
  APPEND ls_xml TO gt_carrier_block.
  CLEAR ls_xml.


  CONCATENATE '<Carrier>'  'HAZUPSOPEN' '</Carrier>' INTO ls_xml.
  APPEND ls_xml TO gt_carrier_block.
  CLEAR ls_xml.


  CONCATENATE '<UserID>' carrierconfig-userid '</UserID>' INTO ls_xml.
  APPEND ls_xml TO gt_carrier_block.
  CLEAR ls_xml.
  CONCATENATE '<Password>' carrierconfig-password '</Password>' INTO ls_xml.
  APPEND ls_xml TO gt_carrier_block.
  CLEAR ls_xml.
  CONCATENATE '<CspKey>' carrierconfig-cspuserid '</CspKey>' INTO ls_xml.
  APPEND ls_xml TO gt_carrier_block.
  CLEAR ls_xml.
  CONCATENATE '<CspPassword>' carrierconfig-csppassword '</CspPassword>' INTO ls_xml.
  APPEND ls_xml TO gt_carrier_block.
  CLEAR ls_xml.
  CONCATENATE '<AccountNumber>' carrierconfig-accountnumber '</AccountNumber>' INTO ls_xml.
  APPEND ls_xml TO gt_carrier_block.
  CLEAR ls_xml.
  CONCATENATE '<MeterNumber>' carrierconfig-metnumber '</MeterNumber>' INTO ls_xml.
  APPEND ls_xml TO gt_carrier_block.
  CLEAR ls_xml.
  APPEND '<CustomerTransactionId/>' TO gt_carrier_block.
  CONCATENATE '<ShipDate>' gs_date '</ShipDate>' INTO ls_xml.
  APPEND ls_xml TO gt_carrier_block.
  CLEAR ls_xml.
  CONCATENATE '<ServiceType>' carrierconfig-servicetype '</ServiceType>' INTO ls_xml.
  APPEND ls_xml TO gt_carrier_block.
  CLEAR ls_xml.

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

  ls_xml = |<AccessToken>| && ls_token-access_token && |</AccessToken>|. APPEND ls_xml TO gt_carrier_block.
  ls_xml = |<RefreshToken>| && ls_token-refresh_token && |</RefreshToken>|. APPEND ls_xml TO gt_carrier_block.


*Request URL build
  DATA : packcount TYPE char3 .
  DATA totalweight(20).
  DATA : lt_packages TYPE TABLE OF /pweaver/ecspackages,
         ls_packages TYPE /pweaver/ecspackages.
  DATA: temp_dimension(15) TYPE c.
  DATA: length(5),width(5),height(5).
  DATA : lt_comd TYPE TABLE OF /pweaver/commodity,
         ls_comd TYPE /pweaver/commodity.
  DATA : lt_hazard TYPE TABLE OF /pweaver/ecshazard,
         ls_hazard TYPE /pweaver/ecshazard,
         gs_hazard TYPE  /pweaver/ecshazard.
  DATA: temp_char(10) TYPE c.
  DATA : lv_dec TYPE p DECIMALS 0 .
*  DATA : wa_hazard LIKE hazard .
*  CLEAR : packcount ,  totalweight ,ls_packages , length,width,height,
*          temp_dimension , ls_comd .
*  REFRESH : lt_packages , lt_comd .
*  lt_packages   = packages[]. "shipment-packages .
*  lt_comd      = int_comd[]. "shipment-intlcomd .
*  LOOP AT hazard INTO ls_hazard.
*    APPEND ls_hazard TO lt_hazard.
*  ENDLOOP.
*    LT_HAZARD    = HAZARD.
  DESCRIBE TABLE  lt_packages LINES packcount .
  LOOP AT lt_packages INTO ls_packages.
    totalweight = totalweight + ls_packages-weight.
  ENDLOOP.

  APPEND '<request>' TO lt_xml.
  APPEND LINES OF gt_carrier_block TO lt_xml.


*Begin of PWC Block
  APPEND '<PWC>' TO lt_xml.
  CONCATENATE '<LabelType>' 'PNG' '</LabelType>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CONCATENATE '<URL>' url '</URL>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  IF removeci = 'X'.
    CONCATENATE '<REMOVEINTERNATIONALFORMS>' 'TRUE' '</REMOVEINTERNATIONALFORMS>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
  ELSE.
    CONCATENATE '<REMOVEINTERNATIONALFORMS>' 'FALSE' '</REMOVEINTERNATIONALFORMS>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
  ENDIF.
  APPEND '<PrinterID> </PrinterID>' TO lt_xml.
  APPEND '</PWC>' TO lt_xml.
*End of PWC Block
****Paperless ETD upload to Carrier
*  DATA: lv_pdf_base64 TYPE string.
*  IF shipment-carrier-paperlessinv IS NOT INITIAL
*    AND ( shipment-otf_tt[] IS NOT INITIAL OR shipment-pdf_xstring IS NOT INITIAL ).
*    APPEND  '<UploadDocument>' TO lt_xml.
*    IF carrierconfig-carriertype = 'UPS'.
*      APPEND '<DocumentType>002</DocumentType>' TO lt_xml.
*    ELSE.
*      APPEND '<DocumentType></DocumentType>' TO lt_xml.
*    ENDIF.
*
*    ls_xml = |<DocumentReference>| && shipment-vbeln && |</DocumentReference>|. APPEND ls_xml TO lt_xml.
*    ls_xml = |<FileName>| && |CI| && shipment-vbeln && sy-datum && |.PDF</FileName>|. APPEND ls_xml TO lt_xml.
*
*    CALL FUNCTION '/PWEAVER/OTF_TO_PDF_BASE64'
*      EXPORTING
*        otf_tt            = shipment-otf_tt
*        pdf_xstring       = shipment-pdf_xstring
*      IMPORTING
*        pdf_base64_string = lv_pdf_base64.
*
*    ls_xml = |<DocumentContent>| && lv_pdf_base64 && |</DocumentContent>|. APPEND ls_xml TO lt_xml.
*    APPEND  '<DocumentFormat>PDF</DocumentFormat>' TO lt_xml.
*    APPEND  '</UploadDocument>' TO lt_xml.
*  ENDIF.
****Paperless ETD upload to Carrier


  APPEND '<Sender>' TO lt_xml.
  CONCATENATE '<CompanyName>' from_company+0(35) '</CompanyName>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  IF from_contact IS NOT INITIAL.
    CONCATENATE '<Contact>' from_contact+0(35) '</Contact>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
  ELSE.
    CONCATENATE '<Contact>' from_company+0(35) '</Contact>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
  ENDIF.
  CONCATENATE '<StreetLine1>' from_address1+0(35) '</StreetLine1>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  CONCATENATE '<StreetLine2>' from_address2+0(35) '</StreetLine2>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml .
  CONCATENATE '<StreetLine3>'  '</StreetLine3>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml .

  CONCATENATE '<City>' from_city '</City>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  CONCATENATE '<StateOrProvinceCode>' from_state '</StateOrProvinceCode>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  CONCATENATE '<PostalCode>' from_postalcode '</PostalCode>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  CONCATENATE '<CountryCode>' from_country '</CountryCode>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.

  IF from_phone IS INITIAL.
    from_phone = '9999999999'.
  ENDIF.
  REPLACE ALL OCCURRENCES OF '(' IN from_phone WITH ''.
  REPLACE ALL OCCURRENCES OF ')' IN from_phone WITH ''.
  REPLACE ALL OCCURRENCES OF '-' IN from_phone WITH ''.
  REPLACE ALL OCCURRENCES OF '.' IN from_phone WITH ''.
  CONDENSE from_phone NO-GAPS.

  CONCATENATE '<Phone>' from_phone '</Phone>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  CONCATENATE '<Email>' shipper_email '</Email>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  CONCATENATE '<TAXID>' '' '</TAXID>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  APPEND '</Sender>' TO lt_xml.

  APPEND '<Origin>' TO lt_xml.
  CONCATENATE '<CompanyName>' from_company+0(35) '</CompanyName>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  IF from_contact IS NOT INITIAL.                                         " We are getting error in the response if contact tag is empty.
    CONCATENATE '<Contact>' from_contact+0(35) '</Contact>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
  ELSE.
    CONCATENATE '<Contact>' from_company+0(35)'</Contact>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
  ENDIF.
  CONCATENATE '<StreetLine1>' from_address1+0(35) '</StreetLine1>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  CONCATENATE '<StreetLine2>' from_address2+0(35) '</StreetLine2>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml .
  CONCATENATE '<StreetLine3>'  '</StreetLine3>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml .

  CONCATENATE '<City>' from_city '</City>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  CONCATENATE '<StateOrProvinceCode>' from_state '</StateOrProvinceCode>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  CONCATENATE '<PostalCode>' from_postalcode '</PostalCode>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  CONCATENATE '<CountryCode>' from_country '</CountryCode>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.

  CONCATENATE '<Phone>' from_phone '</Phone>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  CONCATENATE '<Email>' shipper_email '</Email>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  CONCATENATE '<TAXID>' '' '</TAXID>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  APPEND '</Origin>' TO lt_xml.


  APPEND '<Recipient>' TO lt_xml.
  CONCATENATE '<CompanyName>' shipto_company+0(35)  '</CompanyName>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  IF shipto_contact IS NOT INITIAL.
    CONCATENATE '<Contact>' shipto_contact+0(35) '</Contact>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
  ELSE.
    CONCATENATE '<Contact>'  '.' '</Contact>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
  ENDIF.

  CONCATENATE '<StreetLine1>' shipto_address1+0(35) '</StreetLine1>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.

  CONCATENATE '<StreetLine2>' shipto_address2+0(35) '</StreetLine2>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.

  CONCATENATE '<StreetLine3>' shipto_address3+0(35) '</StreetLine3>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.

  CONCATENATE '<City>' shipto_city '</City>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  CONCATENATE '<StateOrProvinceCode>' shipto_state '</StateOrProvinceCode>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  CONCATENATE '<PostalCode>' shipto_postalcode '</PostalCode>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  CONCATENATE '<CountryCode>' shipto_country '</CountryCode>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  IF  shipto_phone IS INITIAL.
    shipto_phone = '9999999999'.
  ENDIF.

  REPLACE ALL OCCURRENCES OF '(' IN shipto_phone WITH ''.
  REPLACE ALL OCCURRENCES OF ')' IN shipto_phone WITH ''.
  REPLACE ALL OCCURRENCES OF '-' IN shipto_phone WITH ''.
  REPLACE ALL OCCURRENCES OF '.' IN shipto_phone WITH ''.
  CONDENSE shipto_phone NO-GAPS.

  CONCATENATE '<Phone>' shipto_phone '</Phone>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  CONCATENATE '<Email>' '' '</Email>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  CONCATENATE '<TAXID>' '' '</TAXID>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  APPEND '</Recipient>' TO lt_xml.

  DATA : soldto_adrnr TYPE tvst-adrnr,
         soldto_adrc  TYPE adrc.


  SELECT SINGLE adrnr FROM tvst INTO soldto_adrnr WHERE vstel = carrierconfig-plant.
  SELECT SINGLE * FROM adrc INTO soldto_adrc WHERE addrnumber = soldto_adrnr.

  APPEND '<SoldTo>' TO lt_xml.
  CONCATENATE '<CompanyName>' shipto_company+0(35) '</CompanyName>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  IF shipto_contact IS NOT INITIAL.
    CONCATENATE '<Contact>' shipto_contact+0(35) '</Contact>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
  ELSE.
    CONCATENATE '<Contact>' '.' '</Contact>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
  ENDIF.
  CONCATENATE '<StreetLine1>' shipto_address1+0(35) '</StreetLine1>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  CONCATENATE '<StreetLine2>'shipto_address2+0(35) '</StreetLine2>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.

  CONCATENATE '<StreetLine3>' shipto_address3+0(35) '</StreetLine3>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.

  CONCATENATE '<City>' shipto_city  '</City>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  CONCATENATE '<StateOrProvinceCode>' shipto_state '</StateOrProvinceCode>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  CONCATENATE '<PostalCode>'  shipto_postalcode '</PostalCode>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  CONCATENATE '<CountryCode>' shipto_country  '</CountryCode>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  CONCATENATE '<Phone>' shipto_phone '</Phone>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  CONCATENATE '<Email>' '' '</Email>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  CONCATENATE '<TAXID>' '' '</TAXID>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  APPEND '</SoldTo>' TO lt_xml.

** Begin of Broker Block
*  IF shipment-carrier-bsoflag = abap_true.
*    ls_broker = shipment-carrier-brokeraddress.
*    APPEND '<Broker>' TO lt_xml.
*    CONCATENATE '<CompanyName>' ls_broker-company '</CompanyName>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*    CONCATENATE '<Contact>' ls_broker-contact '</Contact>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*    CONCATENATE '<StreetLine1>' ls_broker-address1 '</StreetLine1>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*    CONCATENATE '<StreetLine2>' ls_broker-address2 '</StreetLine2>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*
*    CONCATENATE '<StreetLine3>' ls_broker-address3 '</StreetLine3>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*
*
*    CONCATENATE '<City>' ls_broker-city  '</City>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*    CONCATENATE '<StateOrProvinceCode>' ls_broker-state '</StateOrProvinceCode>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*    CONCATENATE '<PostalCode>'  ls_broker-postalcode '</PostalCode>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*    CONCATENATE '<CountryCode>' ls_broker-country '</CountryCode>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*    CONCATENATE '<Phone>' ls_broker-telephone '</Phone>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*    CONCATENATE '<Email>' ls_broker-email '</Email>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*    APPEND '</Broker>' TO lt_xml.
*  ENDIF.
** End of Broker Block

** Begin of Hold Block
*  IF shipment-carrier-hold = abap_true.
*    ls_hold = shipment-carrier-holdlocation.
*    APPEND '<Hold>' TO lt_xml.
*    CONCATENATE '<CompanyName>' ls_hold-company '</CompanyName>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*    CONCATENATE '<Contact>' ls_hold-contact '</Contact>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*    CONCATENATE '<StreetLine1>' ls_hold-address1 '</StreetLine1>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*    CONCATENATE '<StreetLine2>' ls_hold-address2 '</StreetLine2>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*
*    CONCATENATE '<StreetLine3>' ls_hold-address3 '</StreetLine3>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*
*    CONCATENATE '<City>' ls_hold-city  '</City>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*    CONCATENATE '<StateOrProvinceCode>' ls_hold-state '</StateOrProvinceCode>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*    CONCATENATE '<PostalCode>'  ls_hold-postalcode '</PostalCode>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*    CONCATENATE '<CountryCode>' ls_hold-country '</CountryCode>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*    CONCATENATE '<Phone>' ls_hold-telephone '</Phone>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*    CONCATENATE '<Email>' ls_hold-email '</Email>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*    CONCATENATE '<TAXID>' '' '</TAXID>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*    APPEND '</Hold>' TO lt_xml.
*  ENDIF.
** End of Hold Block


  IF paymentcode = 'SENDER' OR paymentcode = 'PREPAID'.
    paymentcode = 'SENDER'.
    APPEND '<Paymentinformation>' TO lt_xml.
    CONCATENATE '<PaymentType>' paymentcode '</PaymentType>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<PayerAccountNumber>' carrierconfig-accountnumber '</PayerAccountNumber>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<PayerCountryCode>' from_country  '</PayerCountryCode>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<PayerAccountZipCode>' from_postalcode '</PayerAccountZipCode>'  INTO ls_xml .
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<CompanyName>' from_company '</CompanyName>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<Contact>' from_contact '</Contact>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<StreetLine1>' from_address1 '</StreetLine1>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<StreetLine2>' from_address2 '</StreetLine2>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<StreetLine3>' '' '</StreetLine3>'  INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<City>'  from_city '</City>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<StateOrProvinceCode>' from_state '</StateOrProvinceCode>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<PostalCode>' from_postalcode '</PostalCode>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<CountryCode>' from_country '</CountryCode>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<Phone>' from_phone '</Phone>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<Email>' ''  '</Email>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    APPEND '</Paymentinformation>' TO lt_xml.

  ELSEIF paymentcode = 'RECIPIENT'.
    APPEND '<Paymentinformation>' TO lt_xml.
    CONCATENATE '<PaymentType>' paymentcode '</PaymentType>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<PayerAccountNumber>' third_pty_account_number '</PayerAccountNumber>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<PayerCountryCode>' shipto_country  '</PayerCountryCode>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<PayerAccountZipCode>' shipto_postalcode '</PayerAccountZipCode>'  INTO ls_xml .
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<CompanyName>' shipto_company '</CompanyName>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<Contact>' shipto_contact '</Contact>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<StreetLine1>' shipto_address1 '</StreetLine1>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<StreetLine2>' shipto_address2 '</StreetLine2>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<StreetLine3>' '' '</StreetLine3>'  INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<City>'  shipto_city '</City>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<StateOrProvinceCode>' shipto_state '</StateOrProvinceCode>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<PostalCode>' shipto_postalcode '</PostalCode>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<CountryCode>' shipto_country '</CountryCode>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<Phone>' shipto_phone '</Phone>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<Email>' ''  '</Email>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    APPEND '</Paymentinformation>' TO lt_xml.

  ELSEIF paymentcode = 'THIRDPARTY'.
    APPEND '<Paymentinformation>' TO lt_xml.
    CONCATENATE '<PaymentType>' paymentcode '</PaymentType>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<PayerAccountNumber>' third_pty_account_number '</PayerAccountNumber>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<PayerCountryCode>' third_country  '</PayerCountryCode>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<PayerAccountZipCode>' third_zip '</PayerAccountZipCode>'  INTO ls_xml .
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<CompanyName>' '' '</CompanyName>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<Contact>' '' '</Contact>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<StreetLine1>' '' '</StreetLine1>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<StreetLine2>' '' '</StreetLine2>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<StreetLine3>' '' '</StreetLine3>'  INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<City>'  '' '</City>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<StateOrProvinceCode>'  '</StateOrProvinceCode>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<PostalCode>' third_zip '</PostalCode>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    IF third_country IS NOT INITIAL.
      CONCATENATE '<CountryCode>' third_country '</CountryCode>' INTO ls_xml.
      APPEND ls_xml TO lt_xml.
      CLEAR ls_xml.
    ELSE.
      CONCATENATE '<CountryCode>' shipto_country '</CountryCode>' INTO ls_xml.
      APPEND ls_xml TO lt_xml.
      CLEAR ls_xml.
    ENDIF.
    CONCATENATE '<Phone>' '' '</Phone>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<Email>'   '</Email>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    APPEND '</Paymentinformation>' TO lt_xml.
  ELSE.
    APPEND '<Paymentinformation>' TO lt_xml.
    CONCATENATE '<PaymentType>' paymentcode '</PaymentType>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<PayerAccountNumber>' third_pty_account_number '</PayerAccountNumber>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<PayerCountryCode>' third_country  '</PayerCountryCode>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<PayerAccountZipCode>' third_zip '</PayerAccountZipCode>'  INTO ls_xml .
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    APPEND '</Paymentinformation>' TO lt_xml.
  ENDIF.

*  APPEND '<FreightShipmentDetail>' TO lt_xml.
*  CONCATENATE '<FreightAccountNumber>'  '</FreightAccountNumber>' INTO ls_xml.
*  APPEND ls_xml TO lt_xml.
*  CLEAR ls_xml.
*  CONCATENATE '<CompanyName>'  '</CompanyName>' INTO ls_xml.
*  APPEND ls_xml TO lt_xml.
*  CLEAR ls_xml.
*  CONCATENATE '<Contact>'  '</Contact>' INTO ls_xml.
*  APPEND ls_xml TO lt_xml.
*  CLEAR ls_xml.
*  CONCATENATE '<StreetLine1>'  '</StreetLine1>' INTO ls_xml.
*  APPEND ls_xml TO lt_xml.
*  CLEAR ls_xml.
*  APPEND '<StreetLine2/>' TO lt_xml.
*  APPEND '<StreetLine3/>' TO lt_xml.
*  CONCATENATE '<City>' '</City>' INTO ls_xml.
*  APPEND ls_xml TO lt_xml.
*  CLEAR ls_xml.
*  CONCATENATE '<StateOrProvinceCode>' '</StateOrProvinceCode>' INTO ls_xml.
*  APPEND ls_xml TO lt_xml.
*  CLEAR ls_xml.
*  CONCATENATE '<PostalCode>' '</PostalCode>' INTO ls_xml.
*  APPEND ls_xml TO lt_xml.
*  CLEAR ls_xml.
*  CONCATENATE '<CountryCode>' '</CountryCode>' INTO ls_xml.
*  APPEND ls_xml TO lt_xml.
*  CLEAR ls_xml.
*  CONCATENATE '<Phone>' '</Phone>' INTO ls_xml.
*  APPEND ls_xml TO lt_xml.
*  CLEAR ls_xml.
*  APPEND '<Email/>' TO lt_xml.
*  APPEND '</FreightShipmentDetail>' TO lt_xml.

  CONCATENATE '<PackageCount>' packcount '</PackageCount>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  CONCATENATE '<TotalWeight>' totalweight '</TotalWeight>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.

  LOOP AT tracking_numbers.
    SPLIT tracking_numbers-dimensions AT 'X' INTO length temp_dimension.
    SPLIT temp_dimension AT 'X' INTO width height.

    APPEND '<Packagedetails>' TO lt_xml.
    IF packagingtype IS NOT INITIAL.
      CONCATENATE '<PackagingType>' packagingtype '</PackagingType>' INTO ls_xml.
      APPEND ls_xml TO lt_xml.
      CLEAR ls_xml.
    ELSE.
      CONCATENATE '<PackagingType>' 'YOUR_PACKING' '</PackagingType>' INTO ls_xml.
      APPEND ls_xml TO lt_xml.
      CLEAR ls_xml.
    ENDIF.

    DATA lv_pw_value TYPE p DECIMALS 2.
    lv_pw_value = tracking_numbers-weight.
    tracking_numbers-weight = lv_pw_value.
    CONDENSE tracking_numbers-weight.

    CONCATENATE '<WeightValue>' tracking_numbers-weight '</WeightValue>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<WeightUnits>' carrierconfig-weightunit '</WeightUnits>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.


    SPLIT tracking_numbers-dimensions AT 'X' INTO length temp_dimension.
    SPLIT temp_dimension AT 'X' INTO width height.

    IF length IS INITIAL AND width IS INITIAL AND height IS INITIAL .
      CONCATENATE '<Length>' '1' '</Length>' INTO ls_xml.
      APPEND ls_xml TO lt_xml.
      CLEAR ls_xml.
      CONCATENATE '<Width>' '1' '</Width>' INTO ls_xml.
      APPEND ls_xml TO lt_xml.
      CLEAR ls_xml.
      CONCATENATE '<Height>' '1' '</Height>' INTO ls_xml.
      APPEND ls_xml TO lt_xml.
      CLEAR ls_xml.
    ENDIF .
    IF length IS NOT INITIAL AND width IS NOT INITIAL AND height IS NOT INITIAL .
      CONCATENATE '<Length>' length  '</Length>' INTO ls_xml.
      APPEND ls_xml TO lt_xml.
      CLEAR ls_xml.
      CONCATENATE '<Width>' width '</Width>' INTO ls_xml.
      APPEND ls_xml TO lt_xml.
      CLEAR ls_xml.
      CONCATENATE '<Height>' height '</Height>' INTO ls_xml.
      APPEND ls_xml TO lt_xml.
      CLEAR ls_xml.
    ENDIF .
    CONCATENATE '<DimensionUnit>' carrierconfig-dimensionunit '</DimensionUnit>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
*    IF ls_packages-cod_amount <> 0.
*      CONCATENATE '<CODAmount>' ls_packages-cod_amount '</CODAmount>' INTO ls_xml.
*      APPEND ls_xml TO lt_xml.
*      CLEAR ls_xml.
*      CONCATENATE '<CODCurrencyCode>' shipment-currencyunit '</CODCurrencyCode>' INTO ls_xml.
*      APPEND ls_xml TO lt_xml.
*      CLEAR ls_xml.
*    ELSE.
*      CONCATENATE '<CODAmount>'  '</CODAmount>' INTO ls_xml.
*      APPEND ls_xml TO lt_xml.
*      CLEAR ls_xml.
*      CONCATENATE '<CODCurrencyCode>'  '</CODCurrencyCode>' INTO ls_xml.
*      APPEND ls_xml TO lt_xml.
*      CLEAR ls_xml.
*    ENDIF .
*    DATA: r_cvalue TYPE p DECIMALS 0.
*    DATA temp_char10(20) TYPE c.
*    CLEAR: temp_char10 , r_cvalue.
*    r_cvalue = shipment-carrier-insurance.
*    temp_char10 = r_cvalue.
*    CONDENSE temp_char10.
*    IF NOT shipment-carrier-insurance IS INITIAL.
*      CONCATENATE '<InsuranceAmount>' temp_char10 '</InsuranceAmount>' INTO ls_xml.
*      APPEND ls_xml TO lt_xml.
*      CLEAR ls_xml.
*      CONCATENATE '<InsuranceCurrencyCode>' carrierconfig-currencyunit '</InsuranceCurrencyCode>' INTO ls_xml.
*      APPEND ls_xml TO lt_xml.
*      CLEAR ls_xml.
*    ELSE .
    APPEND '<InsuranceAmount/>' TO lt_xml.
    APPEND '<InsuranceCurrencyCode/>' TO lt_xml.
*    ENDIF.
    CONCATENATE '<CUSTOMERREFERENCE>' reference1 '</CUSTOMERREFERENCE>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<INVOICENUMBER>'  reference2 '</INVOICENUMBER>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    APPEND '<PONUMBER/>' TO lt_xml.

*    IF shipment-carrier-collectiontype IS NOT INITIAL AND ( shipto-country = shipper-country ) AND ls_packages-cod_amount IS NOT INITIAL.
*
*      CONCATENATE '<CODAmount>' ls_packages-cod_amount '</CODAmount>' INTO ls_xml.
*      APPEND ls_xml TO lt_xml.
*      CLEAR ls_xml.
*
*      CONCATENATE '<CodCollectionType>' shipment-carrier-collectiontype '</CodCollectionType>' INTO ls_xml.
*      APPEND ls_xml TO lt_xml.
*      CLEAR ls_xml.
*
*      CONCATENATE '<CODCurrencyCode>' carrierconfig-currencyunit '</CODCurrencyCode>' INTO ls_xml.
*      APPEND ls_xml TO lt_xml.
*      CLEAR ls_xml.
*
*    ENDIF.

*    IF lt_hazard IS NOT INITIAL.
*      READ TABLE lt_hazard INTO ls_hazard WITH KEY exidv = ls_packages-handling_unit.
*      APPEND '<TemplateName/>' TO lt_xml.
*      APPEND '<DangerousGoodsDetail>' TO lt_xml.
*      IF ls_hazard-accessibility IS INITIAL.
*        ls_hazard-accessibility = 'INACCESSIBLE'.
*      ENDIF.
*      IF carrierconfig-servicetype <> 'FEDEX_GROUND'.
*        CONCATENATE '<Accessibility>'  ls_hazard-accessibility  '</Accessibility>' INTO ls_xml.
*        APPEND ls_xml TO lt_xml.
*        CLEAR ls_xml.
*        IF ls_hazard-cargoaircraft = 'X'.
*          CONCATENATE '<CargoAircraftOnly>' 'true' '</CargoAircraftOnly>' INTO ls_xml.
*          APPEND ls_xml TO lt_xml.
*          CLEAR ls_xml.
*        ELSE.
*          CONCATENATE '<CargoAircraftOnly>' 'false' '</CargoAircraftOnly>' INTO ls_xml.
*          APPEND ls_xml TO lt_xml.
*          CLEAR ls_xml.
*        ENDIF.
*      ENDIF.
*      CONCATENATE '<Options>' ls_hazard-dgoption '</Options>' INTO ls_xml.
*      APPEND ls_xml TO lt_xml.
*      CLEAR ls_xml.
*      APPEND '<Containers>' TO lt_xml.
*      IF carrierconfig-servicetype <> 'FEDEX_GROUND'.
*        CONCATENATE '<ContainerType>'  ls_hazard-packagingtype '</ContainerType>' INTO ls_xml.
*        APPEND ls_xml TO lt_xml.
*        CLEAR ls_xml.
*        CONCATENATE '<NumberOfContainers>' ls_hazard-packagecount '</NumberOfContainers>' INTO ls_xml.
*        APPEND ls_xml TO lt_xml.
*        CLEAR ls_xml.
*      ENDIF .
*      LOOP AT lt_hazard INTO gs_hazard WHERE exidv = ls_packages-handling_unit.
*        APPEND '<HazardousCommodities>' TO lt_xml.
*        APPEND '<Description>' TO lt_xml.
*        IF carrierconfig-servicetype = 'FEDEX_GROUND'.
*          CONCATENATE '<Id>' gs_hazard-idnumber  '</Id>' INTO ls_xml.
*          APPEND ls_xml TO lt_xml.
*          CLEAR ls_xml.
*        ELSE .
*          CONCATENATE '<Id>' gs_hazard-idnumber+2(4) '</Id>' INTO ls_xml.
*          APPEND ls_xml TO lt_xml.
*          CLEAR ls_xml.
*        ENDIF.
*        CONCATENATE '<PackingGroup>'  gs_hazard-packinggroup '</PackingGroup>' INTO ls_xml.
*        APPEND ls_xml TO lt_xml.
*        CLEAR ls_xml.
*        APPEND '<PackingDetails>' TO lt_xml.
*        CONCATENATE '<PackingInstructions>' gs_hazard-packinstructions '</PackingInstructions>' INTO ls_xml.
*        APPEND ls_xml TO lt_xml.
*        CLEAR ls_xml.
*        APPEND '</PackingDetails>' TO lt_xml.
*        CONCATENATE '<ProperShippingName>' gs_hazard-propershipname '</ProperShippingName>' INTO ls_xml.
*        APPEND ls_xml TO lt_xml.
*        CLEAR ls_xml.
*        CONCATENATE '<TechnicalName>' gs_hazard-technicalname '</TechnicalName>' INTO ls_xml.
*        APPEND ls_xml TO lt_xml.
*        CLEAR ls_xml.
*        CONCATENATE '<HazardClass>' gs_hazard-classordivision '</HazardClass>' INTO ls_xml.
*        APPEND ls_xml TO lt_xml.
*        CLEAR ls_xml.
*        CONCATENATE '<LabelText>' gs_hazard-typedotlabels '</LabelText>' INTO ls_xml.
*        APPEND ls_xml TO lt_xml.
*        CLEAR ls_xml.
*        APPEND '</Description>' TO lt_xml.
*        APPEND '<Quantity>' TO lt_xml.
*        CONCATENATE '<Amount>' gs_hazard-quantity '</Amount>' INTO ls_xml.
*        APPEND ls_xml TO lt_xml.
*        CLEAR ls_xml.
*        CONCATENATE '<Units>' gs_hazard-units '</Units>' INTO ls_xml.
*        APPEND ls_xml TO lt_xml.
*        CLEAR ls_xml.
*        APPEND '</Quantity>' TO lt_xml.
*        APPEND '</HazardousCommodities>' TO lt_xml.
*      ENDLOOP .
*      APPEND '</Containers>' TO lt_xml.
*      IF carrierconfig-servicetype = 'FEDEX_GROUND'.
*        APPEND '<Packaging>' TO lt_xml.
*        CONCATENATE '<Count>' ls_hazard-packagecount '</Count>' INTO ls_xml.
*        APPEND ls_xml TO lt_xml.
*        CLEAR ls_xml.
*        CONCATENATE '<Units>' ls_hazard-packagecount '</Units>' INTO ls_xml.
*        APPEND ls_xml TO lt_xml.
*        CLEAR ls_xml.
*        APPEND '</Packaging>' TO lt_xml.
*      ENDIF .
*
*      DATA  : full_user_name TYPE addr3_val-name_text,
*              lv_dginfoname  TYPE char35,
*              lv_dginfoplace TYPE char50,
*              lv_dginfotitle TYPE char50.
*
*      IF shipment-dginfo-name IS INITIAL.
*        CALL FUNCTION 'USER_NAME_GET'
*          IMPORTING
*            full_user_name = full_user_name.
*
*        lv_dginfoname = full_user_name.
*        CONCATENATE shipper-city ',' shipper-state INTO lv_dginfoplace SEPARATED BY space.
*        lv_dginfotitle = 'SHIPPER'.
*      ELSE.
*        lv_dginfoname = shipment-dginfo-name.
*      ENDIF.
*
*      APPEND '<Signatory>' TO lt_xml.
*      CONCATENATE '<ContactName>' lv_dginfoname '</ContactName>' INTO ls_xml.
*      APPEND ls_xml TO lt_xml.
*      CLEAR ls_xml.
*      CONCATENATE '<Title>' lv_dginfotitle '</Title>' INTO ls_xml.
*      APPEND ls_xml TO lt_xml.
*      CLEAR ls_xml.
*      CONCATENATE '<Place>' lv_dginfoplace '</Place>' INTO ls_xml.
*      APPEND ls_xml TO lt_xml.
*      CLEAR ls_xml.
*      APPEND '</Signatory>' TO lt_xml.
*      CONCATENATE '<EmergencyContactNumber>' ls_hazard-emergencyphone '</EmergencyContactNumber>' INTO ls_xml.
*      APPEND ls_xml TO lt_xml.
*      CLEAR ls_xml.
*      CONCATENATE '<Offeror>' ls_hazard-emergencycontact '</Offeror>' INTO ls_xml.
*      APPEND ls_xml TO lt_xml.
*      CLEAR ls_xml.
*      APPEND '</DangerousGoodsDetail>' TO lt_xml.
*    ENDIF.


    APPEND '</Packagedetails>' TO lt_xml.
    CLEAR : ls_packages .
  ENDLOOP .

  APPEND '<Referencedetails>' TO lt_xml.
  CONCATENATE '<CustomerReferenceNumber>' reference1 '</CustomerReferenceNumber>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  CONCATENATE '<InvoiceNumber>'  reference2 '</InvoiceNumber>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
  APPEND '<PoNumber/>' TO lt_xml.
  APPEND '</Referencedetails>' TO lt_xml.


*  APPEND '<PickupInformation>' TO lt_xml.
*  CONCATENATE '<PickupDate>' '</PickupDate>' INTO ls_xml.
*  APPEND ls_xml TO lt_xml.
*  CLEAR ls_xml.
*  CONCATENATE '<EarliestTimeReady>'  '</EarliestTimeReady>' INTO ls_xml.
*  APPEND ls_xml TO lt_xml.
*  CLEAR ls_xml.
*  CONCATENATE '<LatestTimeReady>'  '</LatestTimeReady>' INTO ls_xml.
*  APPEND ls_xml TO lt_xml.
*  CLEAR ls_xml.
*  CONCATENATE '<ContactName>'  '</ContactName>' INTO ls_xml.
*  APPEND ls_xml TO lt_xml.
*  CLEAR ls_xml.
*  CONCATENATE '<ContactCompany>' '</ContactCompany>' INTO ls_xml.
*  APPEND ls_xml TO lt_xml.
*  CLEAR ls_xml.
*  CONCATENATE '<ContactPhone>'  '</ContactPhone>' INTO ls_xml.
*  APPEND ls_xml TO lt_xml.
*  CLEAR ls_xml.
*  APPEND '</PickupInformation>' TO lt_xml.



  APPEND '<SpecialServices>' TO lt_xml.
*  IF shipment-carrier-returnshipment IS  NOT INITIAL .
*    CONCATENATE '<ReturnServiceCode>' shipment-carrier-returncarrier '</ReturnServiceCode>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*
*    CONCATENATE '<ReturnLabel>' 'true'  '</ReturnLabel>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*  ELSE .
  CONCATENATE '<ReturnLabel>'  '</ReturnLabel>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.

  CONCATENATE '<ReturnServiceCode>' '</ReturnServiceCode>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
*  ENDIF .
  IF saturday_flag = 'Y' OR saturday_flag = 'Yes' OR saturday_flag = 'YES' OR saturday_flag = 'X'.
    CONCATENATE '<SaturdayDelivery>' 'true'  '</SaturdayDelivery>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
  ELSE.
    CONCATENATE '<SaturdayDelivery>'  '</SaturdayDelivery>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
  ENDIF .

*  IF shipment-carrier-satpickup IS   NOT INITIAL .
*    CONCATENATE '<SaturdayPickup>' 'true' '</SaturdayPickup>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*  ELSE.
*    CONCATENATE '<SaturdayPickup>' 'false' '</SaturdayPickup>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*  ENDIF.
*  IF shipment-carrier-insidepickup IS   NOT INITIAL .
*    CONCATENATE '<InsidePickup>' 'true' '</InsidePickup>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*  ELSE.
*    CONCATENATE '<InsidePickup>' 'false'  '</InsidePickup>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*  ENDIF.
*  IF shipment-carrier-insidedel IS   NOT INITIAL .
*    CONCATENATE '<InsideDelivery>' 'true'  '</InsideDelivery>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*  ELSE.
*    CONCATENATE '<InsideDelivery>' 'false' '</InsideDelivery>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*  ENDIF.
  IF NOT signature1_type IS INITIAL AND shipto_country = from_country.
    CONCATENATE '<SignatureRequired>' 'true'  '</SignatureRequired>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<DeliveryConfirmation>' signature1_type+0(1) '</DeliveryConfirmation>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
  ELSE.
    CONCATENATE '<SignatureRequired>' abap_false  '</SignatureRequired>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
  ENDIF.
*  IF shipment-carrier-residentialdel IS   NOT INITIAL .
*    CONCATENATE '<ResidentialDelivery>' 'true' '</ResidentialDelivery>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*  ELSE.
*    CONCATENATE '<ResidentialDelivery>' 'false' '</ResidentialDelivery>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*  ENDIF.

*  IF shipment-carrier-paperlessinv IS NOT INITIAL.
*    CONCATENATE '<PaperLessInvoice>' 'true' '</PaperLessInvoice>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*  ELSE.
*    CONCATENATE '<PaperLessInvoice>' 'false' '</PaperLessInvoice>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*  ENDIF.


  CONCATENATE '<PrintCommercialInvoice>' 'NO' '</PrintCommercialInvoice>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.


*  IF shipment-carrier-collectiontype IS NOT INITIAL AND ( shipto-country <> shipper-country ).
*    DATA lv_cod TYPE char11.
*    lv_cod = shipment-carrier-codamount.
*    CONDENSE lv_cod.
*    CALL FUNCTION 'CONVERSION_EXIT_ALPHA_OUTPUT'
*      EXPORTING
*        input  = lv_cod
*      IMPORTING
*        output = lv_cod.
*
*    CONCATENATE '<CODAmount>' lv_cod '</CODAmount>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*
*    CONCATENATE '<CodCollectionType>' shipment-carrier-collectiontype '</CodCollectionType>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*
*    CONCATENATE '<CODCurrencyCode>' shipment-currencyunit '</CODCurrencyCode>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*
*  ELSEIF shipment-carrier-collectiontype IS INITIAL.

  APPEND '<CODAmount/>' TO lt_xml.
  APPEND '<CodCollectionType/>' TO lt_xml.
  APPEND '<CODCurrencyCode/>' TO lt_xml.
*  ENDIF.

*  IF shipment-carrier-dryiceweight IS NOT INITIAL.
*    CONCATENATE '<DryIceWeight>' shipment-carrier-dryiceweight '</DryIceWeight>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*  ELSE.
  APPEND '<DryIceWeight/>' TO lt_xml.
*  ENDIF.

  CONCATENATE '<DryIceWeightUnits>' 'false' '</DryIceWeightUnits>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
*  IF shipment-carrier-bsoflag IS NOT INITIAL.
*    CONCATENATE '<BrokerSelectOption>' 'true' '</BrokerSelectOption>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*  ELSE.
  CONCATENATE '<BrokerSelectOption>' 'false' '</BrokerSelectOption>' INTO ls_xml.
  APPEND ls_xml TO lt_xml.
  CLEAR ls_xml.
*  ENDIF.
*  IF shipment-carrier-hold IS NOT INITIAL.
*    CONCATENATE '<HoldAtLocation>' 'true' '</HoldAtLocation>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*  ELSE.
*    CONCATENATE '<HoldAtLocation>' 'false' '</HoldAtLocation>' INTO ls_xml.
*    APPEND ls_xml TO lt_xml.
*    CLEAR ls_xml.
*  ENDIF.
  DATA: ls_product TYPE /pweaver/product.
  SELECT SINGLE * FROM /pweaver/product INTO ls_product WHERE plant = carrierconfig-plant.
  IF email IS NOT INITIAL AND  ls_product-email = 'X'.
    CONCATENATE '<EmailNotification>' 'true' '</EmailNotification>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
  ENDIF.

  APPEND '</SpecialServices>' TO lt_xml.

  IF from_country <> shipto_country.
    DATA : qty1(20) TYPE c,
           qty2(20) TYPE c,
           lv_qty   TYPE char20,
           lv_cunit TYPE char20.

    APPEND '<InternationalDetail>' TO lt_xml.
    CONCATENATE '<ITN>' '' '</ITN>' INTO ls_xml. APPEND ls_xml TO lt_xml.
    LOOP AT int_comd.
      APPEND '<Commodities>' TO lt_xml.
      CONCATENATE '<Description>' int_comd-cdescription+0(30) '</Description>' INTO ls_xml.
      APPEND ls_xml TO lt_xml.
      CLEAR ls_xml.
      CLEAR : qty1 , qty2.
      lv_qty = int_comd-cqty.
      CONDENSE lv_qty.
      SPLIT lv_qty AT '.' INTO qty1 qty2.
      CONDENSE qty1.
      CONCATENATE '<Quantity>'   qty1  '</Quantity>' INTO ls_xml.
      APPEND ls_xml TO lt_xml.
      CLEAR ls_xml.
      CLEAR : temp_char .
      temp_char =  int_comd-cweight.
      CONDENSE temp_char.
      CONCATENATE '<Weight>' temp_char '</Weight>' INTO ls_xml.
      APPEND ls_xml TO lt_xml.
      CLEAR ls_xml.
      CONCATENATE '<CountryOfManufacture>' int_comd-cmfr '</CountryOfManufacture>' INTO ls_xml.
      APPEND ls_xml TO lt_xml.
      CLEAR ls_xml.
      lv_cunit = int_comd-cunitvalue.
      CONDENSE lv_cunit.
      CONCATENATE '<UnitPrice>' lv_cunit '</UnitPrice>' INTO ls_xml.
      APPEND ls_xml TO lt_xml.
      CLEAR ls_xml.
      CONCATENATE '<HarmonizedCode>' int_comd-hcode '</HarmonizedCode>' INTO ls_xml.
      APPEND ls_xml TO lt_xml.
      CLEAR ls_xml.
      APPEND '<PartNumber/>' TO lt_xml.
      APPEND '<ECCN/>' TO lt_xml.
      APPEND '</Commodities>' TO lt_xml.
    ENDLOOP .

    DATA: r_cvalue TYPE p DECIMALS 0.
    r_cvalue = custom_value.
    temp_char = r_cvalue.
    CONDENSE temp_char.
    CONCATENATE '<Totalcustomvalue>' temp_char '</Totalcustomvalue>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<InvoiceNumber>'  '</InvoiceNumber>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<InvoiceDate>'  '</InvoiceDate>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<PurchaseOrderNumber>'  '</PurchaseOrderNumber>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<ReasonForExport>' 'SALE' '</ReasonForExport>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<CurrencyCode>' carrierconfig-currencyunit  '</CurrencyCode>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    IF dtax = 'SENDER'.
      CONCATENATE '<DutiesPaymentType>' dtax '</DutiesPaymentType>' INTO ls_xml.
      APPEND ls_xml TO lt_xml.
      CLEAR ls_xml.
      CONCATENATE '<DutiesAccountNumber>' carrierconfig-accountnumber '</DutiesAccountNumber>' INTO ls_xml.
      APPEND ls_xml TO lt_xml.
      CLEAR ls_xml.
      CONCATENATE '<DutiesCountryCode>' from_country '</DutiesCountryCode>' INTO ls_xml.
      APPEND ls_xml TO lt_xml.
      CLEAR ls_xml.
      CONCATENATE '<DutiesAccountZipCode>' from_postalcode '</DutiesAccountZipCode>' INTO ls_xml.
      APPEND ls_xml TO lt_xml.
      CLEAR ls_xml.
    ELSEIF dtax = 'RECIPIENT'.
      CONCATENATE '<DutiesPaymentType>' dtax '</DutiesPaymentType>' INTO ls_xml.
      APPEND ls_xml TO lt_xml.
      CLEAR ls_xml.
      CONCATENATE '<DutiesAccountNumber>' third_pty_account_number '</DutiesAccountNumber>' INTO ls_xml.
      APPEND ls_xml TO lt_xml.
      CLEAR ls_xml.
      CONCATENATE '<DutiesCountryCode>' shipto_country '</DutiesCountryCode>' INTO ls_xml.
      APPEND ls_xml TO lt_xml.
      CLEAR ls_xml.
      CONCATENATE '<DutiesAccountZipCode>' shipto_postalcode '</DutiesAccountZipCode>' INTO ls_xml.
      APPEND ls_xml TO lt_xml.
      CLEAR ls_xml.
    ELSEIF dtax = 'THIRDPARTY'.
      CONCATENATE '<DutiesPaymentType>' dtax '</DutiesPaymentType>' INTO ls_xml.

      APPEND ls_xml TO lt_xml.
      CLEAR ls_xml.
      IF NOT dtax_account IS INITIAL.
        CONCATENATE '<DutiesAccountNumber>' dtax '</DutiesAccountNumber>' INTO ls_xml.
      ELSE.
        CONCATENATE '<DutiesAccountNumber>' third_pty_account_number '<DutiesAccountNumber>' INTO ls_xml.
      ENDIF.
      APPEND ls_xml TO lt_xml.
      CLEAR ls_xml.
      IF NOT third_country IS INITIAL.
        CONCATENATE '<DutiesCountryCode>' third_country '</DutiesCountryCode>' INTO ls_xml.
      ELSE.
        CONCATENATE '<DutiesCountryCode>' shipto_country '</DutiesCountryCode>' INTO ls_xml.
      ENDIF.
      APPEND ls_xml TO lt_xml.
      CLEAR ls_xml.
      CONCATENATE '<DutiesAccountZipCode>' third_zip '</DutiesAccountZipCode>' INTO ls_xml.
      APPEND ls_xml TO lt_xml.
      CLEAR ls_xml.
    ENDIF.

    CONCATENATE '<FilingOption>' '' '</FilingOption>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
*    IF shipment-carrier-documents = 'X'.
*      CONCATENATE '<DocumentContent>' 'DOCUMENTS' '</DocumentContent>' INTO ls_xml.
*      APPEND ls_xml TO lt_xml.
*      CLEAR ls_xml.
*    ELSE.
*      CONCATENATE '<DocumentContent>' 'NON_DOCUMENTS' '</DocumentContent>' INTO ls_xml.
*      APPEND ls_xml TO lt_xml.
*      CLEAR ls_xml.
*    ENDIF.
    CONCATENATE '<TermsOfSale>' '' '</TermsOfSale>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    CONCATENATE '<BookingConfirmationNumber>' '' '</BookingConfirmationNumber>' INTO ls_xml.
    APPEND ls_xml TO lt_xml.
    CLEAR ls_xml.
    APPEND '</InternationalDetail>' TO lt_xml.
  ENDIF.

  APPEND '</request>' TO lt_xml.


  DATA: carriertext TYPE string.
  LOOP AT lt_xml INTO ls_xml.
    REPLACE ALL OCCURRENCES OF '&' IN ls_xml WITH '&amp;'.
    REPLACE ALL OCCURRENCES OF '''' IN ls_xml WITH '&apos;'.
    MODIFY lt_xml FROM ls_xml INDEX sy-tabix.
    CONCATENATE carriertext ls_xml INTO carriertext .
  ENDLOOP.
  CLEAR : filename .
*  IF communication_URL-cccategory = 'T'.
*    CONCATENATE communication_url-filename '_' delivery_number '_' sy-datlo '_' sy-uzeit '.xml' INTO  filename.

*  ELSE.
*    CONCATENATE communication_url-filename '_' shipment-vbeln '_' sy-datlo '_' sy-uzeit '.xml' INTO  filename.
*  ENDIF.
*dsp

*  CALL FUNCTION '/PWEAVER/PW_COMMUNICATION'
*    EXPORTING
**     shipper          = shipper
***     shipto           = shipto
**     shipment         = shipment
**     product          = product
**     carrierconfig    = carrierconfig
**     printerconfig    = printerconfig
*      ws_req           = request_xml
*      filename         = filename
*      plant            = carrierconfig-plant
*      action           = 'SHIP'
**     NORESPONSE       =
*      carrier_url      = communication_url
**     SM59_DESTINATION =
**     URLSTRING        =
**     xcarrier         = xcarrier
*      request_xml      = lt_xml
**     USERNAME         =
**     PASSWORD         =
**     AUTHORIZATION    =
*    IMPORTING
**     RESPONSE_XML     =
*      ws_resp          = ws_resp
*      trackinginfo     = trackinginfo
**     RESPONSE_XML_OBJECT       = l_xml_document
**     LABELDATA        = labeldata
**     STATUS_LOG       =
**     IPD_DATA         =
**     LT_AES_DATA      =
**    TABLES
**     packages         = packages
*    EXCEPTIONS
*      connection_error = 0
*      OTHERS           = 0.
**********************************************************************
  DATA : file_out  TYPE string,
         file_name TYPE string.
  DATA:lt_filedownload TYPE TABLE OF /pweaver/ecsfile,
       ls_filedownload LIKE LINE OF lt_filedownload.


    CONCATENATE communication_url-filename '_' delivery_number '_' sy-datlo '_' sy-uzeit '.xml' INTO  file_name.

  SELECT  SINGLE * FROM /pweaver/ecsfile INTO ls_filedownload WHERE username = sy-uname.

  IF ls_filedownload-requestpath <> '' AND ls_filedownload-responsepath <> ''.
    CONCATENATE ls_filedownload-requestpath file_name INTO file_out.
  ELSE.
    CONCATENATE 'C:\Shipping\ECS\Request\' file_name INTO file_out.
  ENDIF.


  CALL METHOD cl_gui_frontend_services=>gui_download
    EXPORTING
*     BIN_FILESIZE            =
      filename                = file_out
      filetype                = 'ASC'
*     APPEND                  = SPACE
*     WRITE_FIELD_SEPARATOR   = SPACE
*     HEADER                  = '00'
*     TRUNC_TRAILING_BLANKS   = SPACE
*     WRITE_LF                = 'X'
*     COL_SELECT              = SPACE
*     COL_SELECT_MASK         = SPACE
*     DAT_MODE                = SPACE
*     CONFIRM_OVERWRITE       = SPACE
*     NO_AUTH_CHECK           = SPACE
*     CODEPAGE                = SPACE
*     IGNORE_CERR             = ABAP_TRUE
*     REPLACEMENT             = '#'
*     WRITE_BOM               = SPACE
*     TRUNC_TRAILING_BLANKS_EOL = 'X'
*     WK1_N_FORMAT            = SPACE
*     WK1_N_SIZE              = SPACE
*     WK1_T_FORMAT            = SPACE
*     WK1_T_SIZE              = SPACE
*   IMPORTING
*     FILELENGTH              =
    CHANGING
      data_tab                = lt_xml
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
  IF sy-subrc <> 0.
*  MESSAGE ID SY-MSGID TYPE SY-MSGTY NUMBER SY-MSGNO
*             WITH SY-MSGV1 SY-MSGV2 SY-MSGV3 SY-MSGV4.
  ENDIF.


  DATA : file_in TYPE string.

  IF ls_filedownload-requestpath <> '' AND ls_filedownload-responsepath <> ''.
    CONCATENATE ls_filedownload-responsepath file_name INTO file_in.
  ELSE.
    CONCATENATE 'C:\Shipping\ECS\Response\' file_name INTO file_in.
  ENDIF.



  REFRESH lt_xml.

  DATA : str TYPE string.
  DATA : amount TYPE p DECIMALS 3.
  DATA : str_start TYPE i, str_end TYPE i.

  DATA: counter TYPE i.

  DO 200000 TIMES.
    counter = counter + 1.
    CALL METHOD cl_gui_frontend_services=>gui_upload
      EXPORTING
        filename                = file_in
        filetype                = 'ASC'
*       HAS_FIELD_SEPARATOR     = SPACE
*       HEADER_LENGTH           = 0
*       READ_BY_LINE            = 'X'
*       DAT_MODE                = SPACE
*       CODEPAGE                = SPACE
*       IGNORE_CERR             = ABAP_TRUE
*       REPLACEMENT             = '#'
*       VIRUS_SCAN_PROFILE      =
*    IMPORTING
*       FILELENGTH              =
*       HEADER                  =
      CHANGING
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
        not_supported_by_gui    = 17
        error_no_gui            = 18
        OTHERS                  = 19.
    IF sy-subrc = 0.
      EXIT.
    ENDIF.
  ENDDO.

**********************************************************************



  DATA : count TYPE i VALUE 1.
*  DATA : str TYPE string.
*  DATA : amount TYPE p DECIMALS 3.
*  DATA : str_start TYPE i, str_end TYPE i.

  LOOP AT lt_xml INTO ls_xml.
    str = ls_xml.

* Tracking Number
    IF NOT tracking_numbers[] IS INITIAL.
      IF str CS '<TrackingNumber>'.
        str_start = sy-fdpos + 16.
        IF str CS '</TrackingNumber>'.
          str_end = sy-fdpos - str_start.
          tracking_numbers-trackingnumber = ls_xml+str_start(str_end).
          MODIFY tracking_numbers INDEX count TRANSPORTING trackingnumber.
          count = count + 1.
        ENDIF.
      ENDIF.
    ELSEIF str CS '<TrackingNumber>'.
      str_start = sy-fdpos + 16.
      IF str CS '</TrackingNumber>'.
        str_end = sy-fdpos - str_start.
        tracking_no = ls_xml+str_start(str_end).
      ENDIF.
    ENDIF.

* Sin

    IF str CS '<Sin>'.
      str_start = sy-fdpos + 5.
      IF str CS '</Sin>'.
        str_end = sy-fdpos - str_start.
        tracking_no = ls_xml+str_start(str_end).
      ENDIF.
    ENDIF.

* Freight amount

    IF str CS '<Freight>'.
      str_start = sy-fdpos + 9.
      IF str CS '</Freight>'.
        str_end = sy-fdpos - str_start.
        freight_amt = ls_xml+str_start(str_end).
        CONDENSE freight_amt.
      ENDIF.
    ENDIF.

* Error Message

    IF str CS '<Error>'.
      str_start = sy-fdpos + 7.
      IF str CS '</Error>'.
        str_end = sy-fdpos - str_start.
        error = ls_xml+str_start(str_end).
      ENDIF.
    ENDIF.

    IF str CS '<DiscountedFreight>'.
      str_start = sy-fdpos + 19.
      IF str CS '</DiscountedFreight>'.
        str_end = sy-fdpos - str_start.
        discount_freight = ls_xml+str_start(str_end).
        CONDENSE discount_freight.
      ENDIF.
    ENDIF.

  ENDLOOP.
**********************************************************************
  CHECK lt_xml[] IS NOT INITIAL.
  DATA: response_xml TYPE string.
*        ls_xml       TYPE string.
  DATA : resp_xstring TYPE xstring.

  DATA: l_ixml          TYPE REF TO if_ixml,
        l_streamfactory TYPE REF TO if_ixml_stream_factory,
        l_parser        TYPE REF TO if_ixml_parser,
        l_istream       TYPE REF TO if_ixml_istream,
        l_document      TYPE REF TO if_ixml_document.
  DATA: xml_doc TYPE REF TO cl_xml_document.
*  DATA node TYPE REF TO if_ixml_node.
*  DATA value TYPE string.
*  DATA name TYPE string.
  DATA: nodes     TYPE REF TO if_ixml_node_list,
        iterator1 TYPE REF TO if_ixml_node_iterator,
        nodechild TYPE REF TO if_ixml_node.
*  DATA counter TYPE i.
  DATA: parseerror TYPE REF TO if_ixml_parse_error,
        i          TYPE i,
        index      TYPE i.

  DATA: node  TYPE REF TO if_ixml_node,
        name  TYPE string,
        value TYPE string.

*  DATA : str(100) TYPE c.

  LOOP AT lt_xml INTO ls_xml.
    CONCATENATE response_xml ls_xml INTO response_xml.
  ENDLOOP.

  cl_trex_char_utility=>convert_to_utf8( EXPORTING im_char_string = response_xml
  IMPORTING ex_utf8_string = resp_xstring ).

* Creating the main iXML factory
  CALL METHOD cl_ixml=>create
    RECEIVING
      rval = l_ixml.
* Creating a stream factory
  CALL METHOD l_ixml->create_stream_factory
    RECEIVING
      rval = l_streamfactory.
* Create a stream
  CALL METHOD l_streamfactory->create_istream_xstring
    EXPORTING
      string = resp_xstring
    RECEIVING
      rval   = l_istream.
* Creating a document
  CALL METHOD l_ixml->create_document
    RECEIVING
      rval = l_document.
* Create a Parser
  CALL METHOD l_ixml->create_parser
    EXPORTING
      document       = l_document
      istream        = l_istream
      stream_factory = l_streamfactory
    RECEIVING
      rval           = l_parser.

  IF l_parser->parse( ) NE 0.
    IF l_parser->num_errors( ) NE 0.
      count = l_parser->num_errors( ).
      WRITE: count, ' parse errors have occured:'.
      index = 0.
      WHILE index < count.
        parseerror = l_parser->get_error( index = index ).
        i = parseerror->get_line( ).
        WRITE: 'line: ', i.
        i = parseerror->get_column( ).
        WRITE: 'column: ', i.
        str = parseerror->get_reason( ).
        WRITE: str.
        index = index + 1.
      ENDWHILE.
    ENDIF.
    trackinginfo-errormessage = str.
    RETURN.
  ENDIF.

  l_istream->close( ).
  DATA ls_token1 TYPE /pweaver/tokens.
  CLEAR ls_token1.
***Nevigate to the 'DATA' node of xml
  node = l_document->find_from_name( name = 'AccessToken' ).
  IF NOT node IS INITIAL.
    name = node->get_name( ).
    IF name = 'AccessToken'.
      value = node->get_value( ).
      ls_token1-access_token = value.
    ENDIF.
    CLEAR value.
  ENDIF.

  node = l_document->find_from_name( name = 'RefreshToken' ).
  IF NOT node IS INITIAL.
    name = node->get_name( ).
    IF name = 'RefreshToken'.
      value = node->get_value( ).
      ls_token1-refresh_token = value.
    ENDIF.
    CLEAR value.
  ENDIF.

  IF ls_token1-access_token IS NOT INITIAL AND ls_token1-refresh_token IS NOT INITIAL.
    CALL FUNCTION '/PWEAVER/UPDATE_ACCESS_TOKEN'
      EXPORTING
        carrierconfig = carrierconfig
        access_token  = ls_token1-access_token
        refresh_token = ls_token1-refresh_token
        shipurl       = communication_url.
  ENDIF.

**********************************************************************



ENDFUNCTION.
FORM parse_ship_response TABLES  xml TYPE /pweaver/tt_string
             packages STRUCTURE /pweaver/ecspackages
CHANGING trackinginfo TYPE /pweaver/ecstrack communication_url TYPE  /pweaver/shipurl carrierconfig TYPE /pweaver/cconfig.


  CHECK xml[] IS NOT INITIAL.
  DATA: response_xml TYPE string,
        ls_xml       TYPE string.
  DATA : resp_xstring TYPE xstring.

  DATA: l_ixml          TYPE REF TO if_ixml,
        l_streamfactory TYPE REF TO if_ixml_stream_factory,
        l_parser        TYPE REF TO if_ixml_parser,
        l_istream       TYPE REF TO if_ixml_istream,
        l_document      TYPE REF TO if_ixml_document.
  DATA: xml_doc TYPE REF TO cl_xml_document.
*  DATA node TYPE REF TO if_ixml_node.
*  DATA value TYPE string.
*  DATA name TYPE string.
  DATA: nodes     TYPE REF TO if_ixml_node_list,
        iterator1 TYPE REF TO if_ixml_node_iterator,
        nodechild TYPE REF TO if_ixml_node.
  DATA counter TYPE i.
  DATA: parseerror TYPE REF TO if_ixml_parse_error,
        i          TYPE i,
        index      TYPE i.

  DATA: node  TYPE REF TO if_ixml_node,
        name  TYPE string,
        value TYPE string.

  DATA : str(100) TYPE c.

  LOOP AT xml INTO ls_xml.
    CONCATENATE response_xml ls_xml INTO response_xml.
  ENDLOOP.

  cl_trex_char_utility=>convert_to_utf8( EXPORTING im_char_string = response_xml
  IMPORTING ex_utf8_string = resp_xstring ).

* Creating the main iXML factory
  CALL METHOD cl_ixml=>create
    RECEIVING
      rval = l_ixml.
* Creating a stream factory
  CALL METHOD l_ixml->create_stream_factory
    RECEIVING
      rval = l_streamfactory.
* Create a stream
  CALL METHOD l_streamfactory->create_istream_xstring
    EXPORTING
      string = resp_xstring
    RECEIVING
      rval   = l_istream.
* Creating a document
  CALL METHOD l_ixml->create_document
    RECEIVING
      rval = l_document.
* Create a Parser
  CALL METHOD l_ixml->create_parser
    EXPORTING
      document       = l_document
      istream        = l_istream
      stream_factory = l_streamfactory
    RECEIVING
      rval           = l_parser.

  DATA count TYPE i.
* If Parsing Failes
  IF l_parser->parse( ) NE 0.
    IF l_parser->num_errors( ) NE 0.
      count = l_parser->num_errors( ).
      WRITE: count, ' parse errors have occured:'.
      index = 0.
      WHILE index < count.
        parseerror = l_parser->get_error( index = index ).
        i = parseerror->get_line( ).
        WRITE: 'line: ', i.
        i = parseerror->get_column( ).
        WRITE: 'column: ', i.
        str = parseerror->get_reason( ).
        WRITE: str.
        index = index + 1.
      ENDWHILE.
    ENDIF.
    trackinginfo-errormessage = str.
    RETURN.
  ENDIF.

  l_istream->close( ).
  DATA ls_token1 TYPE /pweaver/tokens.
  CLEAR ls_token1.
***Nevigate to the 'DATA' node of xml
  node = l_document->find_from_name( name = 'AccessToken' ).
  IF NOT node IS INITIAL.
    name = node->get_name( ).
    IF name = 'AccessToken'.
      value = node->get_value( ).
      ls_token1-access_token = value.
    ENDIF.
    CLEAR value.
  ENDIF.

  node = l_document->find_from_name( name = 'RefreshToken' ).
  IF NOT node IS INITIAL.
    name = node->get_name( ).
    IF name = 'RefreshToken'.
      value = node->get_value( ).
      ls_token1-refresh_token = value.
    ENDIF.
    CLEAR value.
  ENDIF.

  IF ls_token1-access_token IS NOT INITIAL AND ls_token1-refresh_token IS NOT INITIAL.
    CALL FUNCTION '/PWEAVER/UPDATE_ACCESS_TOKEN'
      EXPORTING
        carrierconfig = carrierconfig
        access_token  = ls_token1-access_token
        refresh_token = ls_token1-refresh_token
        shipurl       = communication_url.
  ENDIF.

***Nevigate to the 'DATA' node of xml
  node = l_document->find_from_name( name = 'Error' ).
  IF NOT node IS INITIAL.
    name = node->get_name( ).
    IF name = 'Error'.
      value = node->get_value( ).
      trackinginfo-errormessage = value.
    ENDIF.
    CLEAR value.
    RETURN.
  ENDIF.

  node = l_document->find_from_name( name = 'MasterTracking' ).
  IF NOT node IS INITIAL.
    name = node->get_name( ).
    IF name = 'MasterTracking'.
      value = node->get_value( ).
      trackinginfo-mastertracking = value.
      trackinginfo-trackingnumber = value.
    ENDIF.
    CLEAR value.
  ENDIF.
  DATA: mastertrack TYPE REF TO if_ixml_node_collection.
  mastertrack = l_document->get_elements_by_tag_name(  name = 'MasterTrackingId')." 'TrackingNumber').

  DATA: length TYPE i.
  CLEAR value.
  length  = mastertrack->get_length( ).
  CLEAR index.
  WHILE index < length.
    node = mastertrack->get_item( index = index ).
    value = node->get_value( ).
    index = index + 1.
    IF index = length.
      trackinginfo-mastertracking = value.
      trackinginfo-trackingnumber = value.
    ENDIF.
    CLEAR value.
  ENDWHILE.

  nodes = node->get_children( ).
  iterator1 = nodes->create_iterator( ).
  nodechild  = iterator1->get_next( ).
  WHILE NOT nodechild IS INITIAL.
    name = nodechild->get_name( ).
    IF name = 'TrackingNumber'.
      value = nodechild->get_value( ).
      trackinginfo-mastertracking = value.
      trackinginfo-trackingnumber = value.
      EXIT.
    ENDIF.
    CLEAR value.
    nodechild  = iterator1->get_next( ).
  ENDWHILE.

  node = l_document->find_from_name( name = 'TotalFreight' ).
  IF NOT node IS INITIAL.
    name = node->get_name( ).
    IF name = 'TotalFreight'.
      value = node->get_value( ).
      trackinginfo-freightamt = value.
    ENDIF.
    CLEAR value.
  ENDIF.

  node = l_document->find_from_name( name = 'TotalDiscountedFreight' ).
  IF NOT node IS INITIAL.
    name = node->get_name( ).
    IF name = 'TotalDiscountedFreight'.
      value = node->get_value( ).
      trackinginfo-discountamt =  value.
    ENDIF.
    CLEAR value.
  ENDIF.

  node = l_document->find_from_name( name = 'DeliveryDate' ).
  IF NOT node IS INITIAL.
    name = node->get_name( ).
    IF name = 'DeliveryDate'.
      value = node->get_value( ).
      IF NOT value IS INITIAL.
        CALL FUNCTION 'KCD_EXCEL_DATE_CONVERT'
          EXPORTING
            excel_date  = value "fedex format 2014-04-24
            date_format = 'JMT'   "(T) Day,(M) Month,(J) Year
          IMPORTING
            sap_date    = trackinginfo-deliverydate.
      ENDIF.
    ENDIF.
    CLEAR value.
  ENDIF.


  DATA: tracking TYPE REF TO if_ixml_node_collection.
  tracking = l_document->get_elements_by_tag_name(  name = 'Package')." 'TrackingNumber').
  CLEAR length.
*  DATA: length TYPE i.

  length  = tracking->get_length( ).
  CLEAR index.
  WHILE index < length.
    node = tracking->get_item( index = index ).
    value = node->get_value( ).
    index = index + 1.
**   BOC

    nodes = node->get_children( ).
    iterator1 = nodes->create_iterator( ).
    nodechild  = iterator1->get_next( ).

    WHILE nodechild IS NOT INITIAL.
      name = nodechild->get_name( ).
      IF name = 'TrackingNumber'.
        value = nodechild->get_value( ).
        READ TABLE packages INDEX index.
        IF sy-subrc = 0.
          packages-trackingnumber = value.
          MODIFY packages INDEX index TRANSPORTING trackingnumber.
        ENDIF.
        EXIT.
      ENDIF.
* CLEAR value.
      nodechild  = iterator1->get_next( ).
    ENDWHILE.
**   EOC


  ENDWHILE.

  DATA: uspstracking TYPE REF TO if_ixml_node_collection.
  uspstracking = l_document->get_elements_by_tag_name(  name = 'USPSTrackingNumber').



  length  = uspstracking->get_length( ).
  CLEAR index.
  WHILE index < length.
    node = uspstracking->get_item( index = index ).
    value = node->get_value( ).
    index = index + 1.
    READ TABLE packages INDEX index.
    IF sy-subrc = 0.
*      trackinginfo-uspstracking = value.
*      packages-uspstracking = value.
*      MODIFY packages INDEX index TRANSPORTING uspstracking.
    ENDIF.
  ENDWHILE.

  READ TABLE packages INDEX 1.
  IF trackinginfo-trackingnumber IS INITIAL AND trackinginfo-errormessage IS INITIAL." AND packages-carriertype = 'FEDEX'.
    node = l_document->find_from_name_ns( name = 'message' uri    =  'http://www.bea.com/wli/sb/stages/transform/config' ).
    IF NOT node IS INITIAL.
      name = node->get_name( ).
      IF name = 'message'.
        value = node->get_value( ).
        trackinginfo-errormessage = value.
      ENDIF.
      CLEAR value.
      RETURN.
    ENDIF.
*  ELSEIF  packages-carriertype = 'USPS'.
*    node = l_document->find_from_name( name = 'Freight' ).
*    IF NOT node IS INITIAL.
*      name = node->get_name( ).
*      IF name = 'Freight'.
*        value = node->get_value( ).
*        trackinginfo-freightamt = value.
*        trackinginfo-discountamt = value.
*      ENDIF.
*      CLEAR value.
*    ENDIF.
*
*    node = l_document->find_from_name( name = 'Tracking' ).
*    IF NOT node IS INITIAL.
*      name = node->get_name( ).
*      IF name = 'Tracking'.
*        value = node->get_value( ).
*        trackinginfo-mastertracking = value.
*        trackinginfo-trackingnumber = value.
*      ENDIF.
*      CLEAR value.
*    ENDIF.
  ENDIF.
*data: deliverydate type ref to if_ixml_node_collection.
*deliverydate = l_document->get_elements_by_tag_name(  name = 'TrackingNumber').
**
* LENGTH  = deliverydate->GET_LENGTH( ).
*clear index.
*  WHILE INDEX < LENGTH.
*    node = deliverydate->get_item( index = index ).
*    value = node->get_value( ).
*    index = index + 1.
*    read table packages index index.
*    if sy-subrc = 0.
*       packages-deliverydate = value.
*     modify packages index index transporting deliverydate.
*    endif.
*  endwhile.


  IF carrierconfig-carriertype = 'UPS'.
    node = l_document->find_from_name( name = 'ETDDocumentIDs' ).
    IF NOT node IS INITIAL.
      name = node->get_name( ).
      IF name = 'ETDDocumentIDs'.
        value = node->get_value( ).
*        trackinginfo-uspstracking =  value.
      ENDIF.
      CLEAR value.
    ENDIF.
  ENDIF.


ENDFORM.
