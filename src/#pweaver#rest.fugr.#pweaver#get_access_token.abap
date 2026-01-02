FUNCTION /PWEAVER/GET_ACCESS_TOKEN.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(CARRIERCONFIG) TYPE  /PWEAVER/CCONFIG OPTIONAL
*"     VALUE(SHIPURL) TYPE  /PWEAVER/SHIPURL OPTIONAL
*"  EXPORTING
*"     VALUE(TOKENS) TYPE  /PWEAVER/TOKENS
*"----------------------------------------------------------------------
 CONSTANTS: lc_fedex    TYPE char10 VALUE 'FEDEX',
             lc_pod      TYPE char5  VALUE 'POD',
             lc_podimage TYPE char15 VALUE 'PODIMAGE',
             lc_fedexett TYPE char10 VALUE 'FEDEXETT',
             lc_ett_rtg  TYPE char10 VALUE 'ETTRTG'.


  IF ( shipurl-carriertype = lc_fedex OR shipurl-carrieridf = lc_fedex ) AND
  ( shipurl-pwmodule = lc_pod OR shipurl-pwmodule = lc_podimage OR shipurl-pwmodule = lc_ett_rtg ).

    SELECT SINGLE * FROM /pweaver/tokens INTO tokens WHERE carriertype = lc_fedexett.
*                                                     AND accountnumber = carrierconfig-accountnumber.
    IF sy-subrc <> 0.
      RAISE 1.
    ENDIF.

  ELSE.
    SELECT SINGLE * FROM /pweaver/tokens INTO tokens WHERE carriertype = carrierconfig-carriertype
                                                     AND accountnumber = carrierconfig-accountnumber.
    IF sy-subrc <> 0.
      SELECT SINGLE * FROM /pweaver/tokens INTO tokens WHERE carriertype = carrierconfig-carrieridf
                                                       AND accountnumber = carrierconfig-accountnumber.
      IF sy-subrc <> 0.
        RAISE 1.
      ENDIF.
    ENDIF.
  ENDIF.





ENDFUNCTION.
